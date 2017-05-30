# FastClosures

[![Build Status](https://travis-ci.org/c42f/FastClosures.jl.svg?branch=master)](https://travis-ci.org/c42f/FastClosures.jl)

[![Coverage Status](https://coveralls.io/repos/c42f/FastClosures.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/c42f/FastClosures.jl?branch=master)

[![codecov.io](http://codecov.io/github/c42f/FastClosures.jl/coverage.svg?branch=master)](http://codecov.io/github/c42f/FastClosures.jl?branch=master)


A workaround for https://github.com/JuliaLang/julia/issues/15276, in the spirit
of FastAnonymous.jl.

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
