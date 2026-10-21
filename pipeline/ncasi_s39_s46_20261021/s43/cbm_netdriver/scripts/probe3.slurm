#!/bin/bash
#SBATCH -A PUOM0008
#SBATCH -J s43b_probe3
#SBATCH -t 00:15:00
#SBATCH -n 1
#SBATCH -o /fs/scratch/PUOM0008/crsfaaron/ncasi_gates_20261015/s43/cbm_netdriver/logs/probe3_%j.out
source /users/PUOM0008/crsfaaron/cbm_maine/envs/libcbm/bin/activate
python -c "
import importlib
for m in ['rasterio','geopandas','osgeo','fiona','shapely','pyproj']:
    try: importlib.import_module(m); print(m,'ok')
    except Exception as e: print(m,'NO')
"
deactivate
ls -d /users/PUOM0008/crsfaaron/*/envs/* /users/PUOM0008/crsfaaron/*/.venv /users/PUOM0008/crsfaaron/miniconda*/envs/* 2>/dev/null | head -20
module -t avail 2>&1 | grep -i "gdal\|geos\|proj\|python\|miniconda" | head
ls /users/PUOM0008/crsfaaron/R/ 2>/dev/null; ls -d /users/PUOM0008/crsfaaron/R/*/*/terra 2>/dev/null
