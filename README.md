# TethysChlorisCore

[![Stable Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://EPFL-ENAC.github.io/TethysChlorisCore.jl/stable)
[![In development documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://EPFL-ENAC.github.io/TethysChlorisCore.jl/dev)
[![Build Status](https://github.com/EPFL-ENAC/TethysChlorisCore.jl/workflows/Test/badge.svg)](https://github.com/EPFL-ENAC/TethysChlorisCore.jl/actions)
[![Test workflow status](https://github.com/EPFL-ENAC/TethysChlorisCore.jl/actions/workflows/Test.yml/badge.svg?branch=main)](https://github.com/EPFL-ENAC/TethysChlorisCore.jl/actions/workflows/Test.yml?query=branch%3Amain)
[![Lint workflow Status](https://github.com/EPFL-ENAC/TethysChlorisCore.jl/actions/workflows/Lint.yml/badge.svg?branch=main)](https://github.com/EPFL-ENAC/TethysChlorisCore.jl/actions/workflows/Lint.yml?query=branch%3Amain)
[![Docs workflow Status](https://github.com/EPFL-ENAC/TethysChlorisCore.jl/actions/workflows/Docs.yml/badge.svg?branch=main)](https://github.com/EPFL-ENAC/TethysChlorisCore.jl/actions/workflows/Docs.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/EPFL-ENAC/TethysChlorisCore.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/EPFL-ENAC/TethysChlorisCore.jl)
[![DOI](https://zenodo.org/badge/DOI/FIXME)](https://doi.org/FIXME)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![All Contributors](https://img.shields.io/github/all-contributors/EPFL-ENAC/TethysChlorisCore.jl?labelColor=5e1ec7&color=c0ffee&style=flat-square)](#contributors)
[![BestieTemplate](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/JuliaBesties/BestieTemplate.jl/main/docs/src/assets/badge.json)](https://github.com/JuliaBesties/BestieTemplate.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/JuliaDiff/BlueStyle)

This package aims to facilitate the use of the [Tethys-Chloris (T&C) model](https://hyd.ifu.ethz.ch/research-data-models/t-c.html) implementation in Julia by centralizing shared utilities and types that are used by the T&C model and its extensions. The T&C model is a mechanistic model designed to simulate essential components of the hydrological and carbon cycles, resolving exchanges of energy, water, and CO2 between the land surface and the planetary boundary layer with an hourly time step. 

More information regarding the T&C model
* [full description](https://hyd.ifu.ethz.ch/research-data-models/t-c/t-c-full-description.html)
* [original MATLAB code](https://github.com/simonefatichi/TeC_Source_Code)

The TethysChlorisCore.jl package is currently used in
* [TethysChloris.jl](https://github.com/CHANGE-EPFL/TethysChloris.jl)
* [UrbanTethysChloris.jl](https://github.com/simonefatichi/TeC_Source_Code)

## How to Cite

If you use TethysChlorisCore.jl in your work, please cite using the reference given in [CITATION.cff](https://github.com/EPFL-ENAC/TethysChlorisCore.jl/blob/main/CITATION.cff).

## Contributing

If you want to make contributions of any kind, please first that a look into our [contributing guide directly on GitHub](docs/src/90-contributing.md) or the [contributing page on the website](https://EPFL-ENAC.github.io/TethysChlorisCore.jl/dev/90-contributing/)

---

### Contributors

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/hsolleder"><img src="https://avatars.githubusercontent.com/u/9566930?v=4?s=100" width="100px;" alt="H Solleder"/><br /><sub><b>H Solleder</b></sub></a><br /><a href="#code-hsolleder" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/sphamba"><img src="https://avatars.githubusercontent.com/u/17217484?v=4?s=100" width="100px;" alt="Son Pham-Ba"/><br /><sub><b>Son Pham-Ba</b></sub></a><br /><a href="#review-sphamba" title="Reviewed Pull Requests">👀</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->
