"""Vector layers of the example windows: reference fields (California only: DWR Statewide Crop
Mapping 2024, CC0) and FTW global field polygons of the window's imagery year, clipped to each
window and written as WKT tables. Washington (WSDA) and Brazil (CONAB) reference fields are not
distributed under licences that allow redistribution, and the FTW map is not used for Brazil,
whose imagery (2019/20) predates the FTW map.
Usage: python release/fieldborders/data-raw/example_vectors.py <windows.csv> <out_dir>
"""
import sys
from pathlib import Path

import fsspec
import pandas as pd
import pyarrow.compute as pc
import pyarrow.dataset as ds
import shapely

DWR = "data/raw/labels/us_ca_scm/us_ca_scm-2024.parquet"
FTW = {
    "california": "data/raw/products/ftw_global/US_CA.parquet",
    "washington": "data/raw/products/ftw_global/US_WA.parquet",
    "moghan": "https://data.source.coop/ftw/global-data/predictions/vectors/alpha/results-by-admin-conf/admin:country_code=IR/Iran.parquet",
}


def clip(dataset, w, cols, year=None):
    flt = ((pc.field("bbox", "xmax") >= w.west) & (pc.field("bbox", "xmin") <= w.east)
           & (pc.field("bbox", "ymax") >= w.south) & (pc.field("bbox", "ymin") <= w.north))
    t = dataset.to_table(columns=cols + ["geometry"], filter=flt).to_pandas()
    if year is not None:
        t = t[pd.to_datetime(t["determination:datetime"]).dt.year == year]
    g = shapely.intersection(shapely.make_valid(shapely.from_wkb(t["geometry"].values)),
                             shapely.box(w.west, w.south, w.east, w.north))
    t = t.drop(columns="geometry").assign(wkt=shapely.to_wkt(g), area=shapely.area(g))
    return t[t.area > 0]


def dataset(src):
    if src.startswith("https://"):
        return ds.dataset(src, filesystem=fsspec.filesystem("https"), format="parquet")
    return ds.dataset(src, format="parquet")


def main():
    wins = pd.read_csv(sys.argv[1])
    out = Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    for w in wins.itertuples():
        msg = [w.name]
        if w.name == "california":
            f = clip(dataset(DWR), w, ["crop:code"])
            f.rename(columns={"crop:code": "crop_code"})[["crop_code", "wkt"]].to_csv(out / f"{w.name}_fields.csv", index=False)
            msg.append(f"reference fields {len(f)}")
        if w.name in FTW:
            p = clip(dataset(FTW[w.name]), w, ["determination:datetime"], year=int(w.year))
            p[["wkt"]].to_csv(out / f"{w.name}_ftw.csv", index=False)
            msg.append(f"ftw polygons {len(p)} ({int(w.year)})")
        print(" ".join(msg), flush=True)


if __name__ == "__main__":
    main()
