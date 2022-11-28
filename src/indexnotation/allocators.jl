
abstract type AbstractStrategy end;
struct Julia_Managed_Temporaries <: AbstractStrategy end;
struct Cached_Temporaries <: AbstractStrategy end;
struct Malloc_Temporaries <: AbstractStrategy end;

_current_strategy() = Cached_Temporaries();
current_strategy() = Base.invokelatest(_current_strategy);

function change_strategy(strategy::AbstractStrategy)
    @eval TensorOperations TensorOperations._current_strategy() = $strategy
end

use_cache() = current_strategy() isa Cached_Temporaries;

function default_cache_size()
    return min(1<<32, Int(Sys.total_memory())>>2)
end

# methods used for the cache: see implementation/tensorcache.jl for more info
function memsize end
function similar_from_indices end
function similarstructure_from_indices end

taskid() = convert(UInt, pointer_from_objref(current_task()))

const cache = LRU{Any, Any}(; by = memsize, maxsize = default_cache_size())

"""
    enable_cache(; maxsize::Int = ..., maxrelsize::Real = ...)

(Re)-enable the cache for further use; set the maximal size `maxsize` (as number of bytes)
or relative size `maxrelsize`, as a fraction between 0 and 1, resulting in
`maxsize = floor(Int, maxrelsize * Sys.total_memory())`. Default value is `maxsize = 2^30` bytes, which amounts to 1 gigabyte of memory.
"""
function enable_cache(; maxsize::Int = -1, maxrelsize::Real = 0.0)
    if maxsize == -1 && maxrelsize == 0.0
        maxsize = default_cache_size()
    elseif maxrelsize > 0
        maxsize = max(maxsize, floor(Int, maxrelsize*Sys.total_memory()))
    else
        @assert maxsize >= 0
    end
    change_strategy(Cached_Temporaries());
    resize!(cache; maxsize = maxsize)
    return
end

"""
    clear_cache()

Clear the current contents of the cache.
"""
function clear_cache()
    empty!(cache)
    return
end

"""
    cachesize()

Return the current memory size (in bytes) of all the objects in the cache.
"""
cachesize() = cache.currentsize

allocate_similar_from_indices(args...) = allocate_similar_from_indices(current_strategy(),args...)
allocate_similar_from_indices(strategy::Cached_Temporaries, args...) = cached_similar_from_indices(args...)
allocate_similar_from_indices(strategy::Julia_Managed_Temporaries, args...) = similar_from_indices(args...)

deallocate!(var) = deallocate!(current_strategy(),var);
function deallocate!(strategy::Julia_Managed_Temporaries,var) end;

function deallocate!(strategy::Cached_Temporaries,var)
    recy = cache[(typeof(var),structure(var))];
    Recyclers.recycle!(recy,var);
end
