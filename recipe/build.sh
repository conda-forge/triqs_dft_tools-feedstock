#!/usr/bin/env bash

mkdir build
cd build

# Specific setup for cross-compilation
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  # Openmpi
  export OPAL_PREFIX="$PREFIX"

  # Hack for python > 3.11
  py_minor=$( python -c "import sys; print('{}'.format(sys.version_info[1]))" )
  if [[ "$py_minor" -gt "11" ]]; then
    # Change the meson_cross_file.txt (see https://github.com/conda-forge/numpy-feedstock/blob/main/recipe/build.sh)
    echo "python = '${PREFIX}/bin/python'" >> ${CONDA_PREFIX}/meson_cross_file.txt
    echo "[properties]" >> ${CONDA_PREFIX}/meson_cross_file.txt
    echo "longdouble_format = 'IEEE_DOUBLE_LE'" >> ${CONDA_PREFIX}/meson_cross_file.txt

    # Change the f2py module to use meson for cross compilation
    f2py_file=${BUILD_PREFIX}/lib/python3.${py_minor}/site-packages/numpy/f2py/_backends/_meson.py
    sed "s|\"setup\",|\"setup\"] + [x for x in \"${MESON_ARGS}\".split()] + [|" ${f2py_file} > tmp_file
    cp tmp_file ${f2py_file}
  fi
fi

export FC=${BUILD_PREFIX}/bin/$(basename ${FC})
export CC=${BUILD_PREFIX}/bin/$(basename ${CC})
export CXX=${BUILD_PREFIX}/bin/$(basename ${CXX})

export CXXFLAGS="$CXXFLAGS -D_LIBCPP_DISABLE_AVAILABILITY"
source $PREFIX/share/triqs/triqsvars.sh

cmake ${CMAKE_ARGS} \
    -DCMAKE_INSTALL_PREFIX=$PREFIX \
    -DCMAKE_BUILD_TYPE=Release \
    ..

make -j1 VERBOSE=1

if [[ "${CONDA_BUILD_CROSS_COMPILATION}" != "1" ]]; then
  CTEST_OUTPUT_ON_FAILURE=1 ctest
fi

make install
