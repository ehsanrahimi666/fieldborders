# Plot theme and colours of the package

Plot theme and colours of the package

## Usage

``` r
fb_theme(base_size = 10)
```

## Arguments

- base_size:

  Base font size.

## Value

A `ggplot2` theme.

## Examples

``` r
library(ggplot2)
ggplot(data.frame(x = 1:3, y = 1:3), aes(x, y)) + geom_point() + fb_theme()
```
