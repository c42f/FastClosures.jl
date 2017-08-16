__precompile__()

module FastClosures
using Compat

using Base.Meta

export @closure

"""
    wrap_closure(module_, closure_expression)

Wrap `closure_expression` in a `let` block to improve efficiency.  Using this
rather than `@closure` is necessary when interpolating variables into the
closure expression.  (Interpolation happens only *after* the macro sees the
expression.)  See the docs for `@closure` for additional detail.

Example: you should use

```
result = :(i)
quote
    \$(wrap_closure(current_module(), :(()->\$result)))
end
```

rather than

```
result = :(i)
quote
    @closure ()->\$result
end
```
"""
function wrap_closure(module_, closure_expression)
    ex = macroexpand(module_, closure_expression)
    if isexpr(ex, :error)
        # There was an error in macroexpand - just return the original
        # expression so that the user gets a comprehensible error message.
        return esc(closure_expression)
    end
    if isexpr(ex, :(->))
        args1 = ex.args[1]
        if isa(args1, Symbol)
            funcargs = [args1]
        else
            @assert isexpr(args1, :tuple)
            funcargs = args1.args
        end
    elseif isexpr(ex, :function)
        @assert isexpr(ex.args[1], :call)
        funcargs = ex.args[1].args[2:end]
    else
        throw(ArgumentError("Argument to @closure must be a closure!  (Got $closure_expression)"))
    end
    # FIXME support type assertions and kw args
    bound_vars = Symbol[funcargs...]
    @assert isa(ex.args[2], Expr) && ex.args[2].head == :block
    captured_vars = Symbol[]
    find_var_uses!(captured_vars, bound_vars, ex.args[2])
    quote
        let $([:($(esc(v))=$(esc(v))) for v in captured_vars]...)
            $(esc(closure_expression))
        end
    end
end

"""
    @closure closure_expression

Wrap the closure definition `closure_expression` in a let block to encourage
the julia compiler to generate improved type information.  For example:

```julia
callfunc(f) = f()

function foo(n)
   for i=1:n
       if i >= n
           # Unlikely event - should be fast.  However, capture of `i` inside
           # the closure confuses the julia-0.6 compiler and causes it to box
           # the variable `i`, leading to a 100x performance hit if you remove
           # the `@closure`.
           callfunc(@closure ()->println("Hello \$i"))
       end
   end
end
```

See `wrap_closure()` for cases where you want to interpolate an expression into
the closure wrapped by `@closure`.

There's nothing nice about this - it's a heuristic workaround for some
inefficiencies in the type information inferred by the julia 0.6 compiler.
However, it can result in large speedups in many cases, without the need to
restructure the code to avoid the closure.
"""
macro closure(ex)
    module_ = Compat.macros_have_sourceloc ?  __module__ : current_module()
    wrap_closure(module_, ex)
end

# Find arguments in closure arg list
#FIXME function find_closure_args(ex)
#end

# Utility function - fill `varlist` with all accesses to variables inside `ex`
# which are not bound before being accessed.  Variables which were bound
# before access are returned in `bound_vars` as a side effect.
#
# With works with the surface syntax so it unfortunately has to reproduce some
# of the lowering logic (and consequently likely has bugs!)
function find_var_uses!(varlist, bound_vars, ex)
    if isa(ex, Symbol)
        if !(ex in bound_vars)
            ex ∈ varlist || push!(varlist, ex)
        end
        return varlist
    elseif isa(ex, Expr)
        if ex.head == :quote || ex.head == :line
            return varlist
        end
        if ex.head == :(=)
            find_var_uses_lhs!(varlist, bound_vars, ex.args[1])
            find_var_uses!(varlist, bound_vars, ex.args[2])
        elseif ex.head == :kw
            find_var_uses!(varlist, bound_vars, ex.args[2])
        elseif ex.head == :for || ex.head == :while || ex.head == :comprehension || ex.head == :let
            # New scopes
            inner_bindings = copy(bound_vars)
            find_var_uses!(varlist, inner_bindings, ex.args)
        elseif ex.head == :try
            # New scope + ex.args[2] is a new binding
            find_var_uses!(varlist, copy(bound_vars), ex.args[1])
            catch_bindings = copy(bound_vars)
            !isa(ex.args[2], Symbol) || push!(catch_bindings, ex.args[2])
            find_var_uses!(varlist,catch_bindings,ex.args[3])
            if length(ex.args) > 3
                finally_bindings = copy(bound_vars)
                find_var_uses!(varlist,finally_bindings,ex.args[4])
            end
        elseif ex.head == :call
            find_var_uses!(varlist, bound_vars, ex.args[2:end])
        elseif ex.head == :local
            foreach(ex.args) do e
                if !isa(e, Symbol)
                    find_var_uses!(varlist, bound_vars, e)
                end
            end
        else
            find_var_uses!(varlist, bound_vars, ex.args)
        end
    end
    varlist
end

find_var_uses!(varlist, bound_vars, exs::Vector) = foreach(e->find_var_uses!(varlist, bound_vars, e), exs)

# Find variable uses on the left hand side of an assignment.  Some of what may
# be variable uses turn into bindings in this context (cf. tuple unpacking).
function find_var_uses_lhs!(varlist, bound_vars, ex)
    if isa(ex, Symbol)
        ex ∈ bound_vars || push!(bound_vars, ex)
    elseif isa(ex, Expr)
        if ex.head == :tuple
            find_var_uses_lhs!(varlist, bound_vars, ex.args)
        else
            find_var_uses!(varlist, bound_vars, ex.args)
        end
    end
end

find_var_uses_lhs!(varlist, bound_vars, exs::Vector) = foreach(e->find_var_uses_lhs!(varlist, bound_vars, e), exs)


end # module
