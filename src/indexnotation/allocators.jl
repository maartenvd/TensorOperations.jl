function allocate_similar_from_indices(sym::Symbol, args...)
    if _temporary_strategy[] == CACHED_TEMPORARIES
        cached_similar_from_indices(sym, args...)    
    
    elseif _temporary_strategy[] == JULIA_MANAGED_TEMPORARIES
        similar_from_indices(args...)
    else
        allocate_similar_from_indices(args...)
    end
end

function deallocate!(var)
    if _temporary_strategy[] == MALLOC_TEMPORARIES
        # to avoid name collisions or having to load in big dependencies, should we just require the user to specialize on an unexported unsafe_free! ?
        unsafe_free!(var)
    end
    # otherwise, they are managed by julia or cached, and should not be touched.
end

function unsafe_free!() end;