@testset "Virtual data production behavior" begin
    function wait_until(predicate; attempts=1_000)
        for _ in 1:attempts
            predicate() && return true
            yield()
        end
        return predicate()
    end

    @testset "stale pages and cooperative cancellation" begin
        started = Channel{Any}(8)
        releases = Dict{UInt64,Channel{Nothing}}()
        loader = function (page, page_size, generation, query, token)
            release = Channel{Nothing}(1)
            releases[generation] = release
            put!(started, (page, generation, query, token))
            take!(release)
            return PageResult([Int(generation)]; total_length=1, complete=true)
        end
        source = PagedDataSource{Int,Int}(loader; page_size=1, max_inflight_pages=2)

        @test request_items!(source, 1:1) == [1]
        @test wait_until(() -> isready(started))
        first_request = take!(started)
        first_generation = first_request[2]
        first_token = first_request[4]
        @test !data_request_cancelled(first_token)

        cancel_data_requests!(source)
        @test data_request_cancelled(first_token)
        @test inflight_page_count(source) == 0
        @test request_items!(source, 1:1) == [1]
        @test wait_until(() -> isready(started))
        second_request = take!(started)
        second_generation = second_request[2]
        @test second_generation != first_generation

        put!(releases[first_generation], nothing)
        @test wait_until(() -> isready(source.completions))
        @test poll_data_updates!(source) == 1
        @test fetch_slots(source, 1:1; request=false)[1].kind == LoadingSlot

        put!(releases[second_generation], nothing)
        @test wait_until(() -> isready(source.completions))
        @test poll_data_updates!(source) == 1
        slot = fetch_slots(source, 1:1; request=false)[1]
        @test slot.kind == ReadySlot
        @test slot.item == Int(second_generation)
    end

    @testset "query replacement cancels and isolates request snapshots" begin
        started = Channel{Any}(4)
        release = Channel{Nothing}(4)
        loader = function (page, page_size, generation, query, token)
            put!(started, (query, token))
            take!(release)
            PageResult([query.search === nothing ? "none" : query.search]; complete=true)
        end
        initial = DataQuery(search="old", filters=Dict(:status => "open"), revision=1)
        source = PagedDataSource{String,Int}(loader; page_size=1, query=initial)
        request_items!(source, 1:1)
        @test wait_until(() -> isready(started))
        old_query, old_token = take!(started)

        initial.filters[:status] = "mutated"
        @test old_query.filters[:status] == "open"
        set_data_query!(source, DataQuery(search="new", revision=2))
        @test data_request_cancelled(old_token)
        put!(release, nothing)
        @test wait_until(() -> isready(source.completions))
        poll_data_updates!(source)
        @test page_cache_size(source) == 0
    end

    @testset "failure surfaces and retry recovers" begin
        attempts = Ref(0)
        loader = function (page, page_size, generation)
            attempts[] += 1
            attempts[] == 1 && error("temporary page failure")
            PageResult([42]; total_length=1, complete=true)
        end
        source = PagedDataSource{Int,Int}(loader; page_size=1)
        request_items!(source, 1:1)
        @test wait_until(() -> isready(source.completions))
        poll_data_updates!(source)
        failed = fetch_slots(source, 1:1; request=false)[1]
        @test failed.kind == FailedSlot
        @test failed.error[1] isa ErrorException

        @test retry_page!(source, 1)
        @test wait_until(() -> isready(source.completions))
        poll_data_updates!(source)
        recovered = fetch_slots(source, 1:1; request=false)[1]
        @test recovered.kind == ReadySlot
        @test recovered.item == 42
        @test attempts[] == 2
    end

    @testset "least-recently-used pages are evicted" begin
        loader = (page, page_size, generation) -> PageResult(
            [page];
            total_length=3,
            complete=page == 3,
        )
        source = PagedDataSource{Int,Int}(
            loader;
            page_size=1,
            max_cached_pages=2,
            max_inflight_pages=3,
        )
        @test request_items!(source, 1:3) == [1, 2, 3]
        @test wait_until(() -> isready(source.completions))
        @test wait_until(() -> begin
            poll_data_updates!(source)
            inflight_page_count(source) == 0
        end)
        @test page_cache_size(source) == 2
        slots = fetch_slots(source, 1:3; request=false)
        @test slots[1].kind == LoadingSlot
        @test slots[2].kind == ReadySlot
        @test slots[3].kind == ReadySlot
    end

    @testset "selection follows stable item keys" begin
        source = VectorDataSource(
            [(id=:alpha, value=1), (id=:beta, value=2), (id=:gamma, value=3)];
            key=(item, index) -> item.id,
        )
        state = VirtualListState{Symbol}(viewport_size=3, multiple=true)
        slots = fetch_slots(source, 1:3)
        @test select_virtual_index!(state, slots[2])
        @test state.selected == Set([:beta])

        replace_data!(source, [
            (id=:gamma, value=30),
            (id=:alpha, value=10),
            (id=:beta, value=20),
        ])
        moved = fetch_slots(source, 1:3)
        beta = only(slot for slot in moved if slot.key == :beta)
        @test beta.index == 3
        @test state.selected == Set([:beta])

        reconcile_virtual_selection!(state, (slot.key for slot in moved if slot.key != :beta))
        @test isempty(state.selected)
    end
end
