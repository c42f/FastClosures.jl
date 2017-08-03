# FastClosures

[![Build Status](https://travis-ci.org/c42f/FastClosures.jl.svg?branch=master)](https://travis-ci.org/c42f/FastClosures.jl)

[![Coverage Status](https://coveralls.io/repos/c42f/FastClosures.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/c42f/FastClosures.jl?branch=master)

[![codecov.io](http://codecov.io/github/c42f/FastClosures.jl/coverage.svg?branch=master)](http://codecov.io/github/c42f/FastClosures.jl?branch=master)


A workaround for https://github.com/JuliaLang/julia/issues/15276, for julia-0.6,
somewhat in the spirit of FastAnonymous.jl.  Provides the `@closure` macro,
which wraps a closure in a `let` block to make reading variable bindings private
to the closure.  In certain cases, this make using the closure - and the code
surrouding it - much faster.  Note that it's not clear that the `let` block
trick implemented in this package helps at all in julia-0.5.  However, julia-0.5
compatibility is provided for backward compatibility convenience.

## Interface

```julia
    @closure closure_expression
```

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


Here's a further example of where this helps:

```julia
using FastClosures

# code_warntype problem
function f1()
    if true
    end
    r = 1
    cb = ()->r
    identity(cb)
end

# code_warntype clean
function f2()
    if true
    end
    r = 1
    cb = @closure ()->r
    identity(cb)
end

@code_warntype f1()
@code_warntype f2()
```

