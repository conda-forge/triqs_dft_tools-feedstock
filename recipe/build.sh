#!/usr/bin/env bash

mkdir build
cd build

# Specific setup for cross-compilation
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  # Openmpi
  export OPAL_PREFIX="$PREFIX"

  # Hack for python 3.12
  py_version=$( python -c "import sys; print('{}.{}'.format(sys.version_info[0], sys.version_info[1]))" )
  if [[ "$py_version" == "3.12" ]]; then
    # Change the meson_cross_file.txt (see https://github.com/conda-forge/numpy-feedstock/blob/main/recipe/build.sh)
    echo "python = '${PREFIX}/bin/python'" >> ${CONDA_PREFIX}/meson_cross_file.txt
    echo "[properties]" >> ${CONDA_PREFIX}/meson_cross_file.txt
    echo "longdouble_format = 'IEEE_DOUBLE_LE'" >> ${CONDA_PREFIX}/meson_cross_file.txt

    # Change the f2py module to use meson for cross compilation
    f2py_file=${BUILD_PREFIX}/lib/python3.12/site-packages/numpy/f2py/_backends/_meson.py
    sed "s|\"setup\",|\"setup\"] + [x for x in \"${MESON_ARGS}\".split()] + [|" ${f2py_file} > tmp_file
    cp tmp_file ${f2py_file}
  fi
fi

export FC=${BUILD_PREFIX}/bin/$(basename ${FC})
export CC=${BUILD_PREFIX}/bin/$(basename ${CC})
export CXX=${BUILD_PREFIX}/bin/$(basename ${CXX})

# Openmpi Specific environment setup - Cf. https://github.com/conda-forge/libnetcdf-feedstock/pull/80
export OMPI_MCA_btl=self,tcp
export OMPI_MCA_plm=isolated
export OMPI_MCA_rmaps_base_oversubscribe=yes
export OMPI_MCA_btl_vader_single_copy_mechanism=none
mpiexec="mpiexec --allow-run-as-root"

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
