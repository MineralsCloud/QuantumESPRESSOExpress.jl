# Troubleshooting

This page collects some possible errors you may encounter and trick how to fix them.
If you have some questions about how to use this code, you are welcome to
[discuss with us](https://github.com/MineralsCloud/QuantumESPRESSOExpress.jl/discussions).

_If you have additional tips, please either
[report an issue](https://github.com/MineralsCloud/QuantumESPRESSOExpress.jl/issues/new) or
[submit a PR](https://github.com/MineralsCloud/QuantumESPRESSOExpress.jl/compare) with suggestions._

## Installation problems

### I cannot find the `julia` executable

Make sure you have Julia installed in your environment. Please download the latest
[stable version](https://julialang.org/downloads/#current_stable_release) for your platform.
If you are using a *nix system, the recommended way is to use
[`juliaup`](https://github.com/JuliaLang/juliaup). If you do not want to install `juliaup`
or you are using other platforms that Julia supports, download the corresponding binaries.
Then, create a symbolic link to the Julia executable. If the path is not in your `$PATH`
environment variable, export it to your `$PATH`.

Some clusters, like
[`Habanero`](https://confluence.columbia.edu/confluence/display/rcs/Habanero+HPC+Cluster+User+Documentation),
[`Comet`](https://www.sdsc.edu/support/user_guides/comet.html),
or [`Expanse`](https://www.sdsc.edu/services/hpc/expanse/index.html),
already have Julia installed as a module, you may
just `module load julia` to use it. If not, either install by yourself or contact your
administrator.

## Loading `QuantumESPRESSOExpress`

### Why is Julia compiling/loading modules so slow? What can I do?

First, we recommend you download the latest version of Julia. Usually, the newest version
has the best performance.

If you just want Julia to do a simple task and only once, you could start the Julia REPL with

```bash
julia --compile=min
```

to minimize compilation or

```bash
julia --optimize=0
```

to minimize optimizations, or just use both. Or you could make a system image
and run with

```bash
julia --sysimage custom-image.so
```

See [Fredrik Ekre's talk](https://youtu.be/IuwxE3m0_QQ?t=313) for details.
