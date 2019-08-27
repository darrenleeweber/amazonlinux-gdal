FROM lambci/lambda:build-python3.6

# Provide GIS libs for AWS serverless solutions.  Use conda to install binaries
# and python packages for geospatial computing.  The geopandas project provides
# conda install options that package everything, see:
# http://geopandas.org/install.html

# labda runtime: /var/task
# labda layer: /opt
ARG prefix=/opt
ENV PREFIX=${prefix}

ARG py_version=3.6
ENV PY_VERSION=${py_version}

# numpy 1.17 requires an explicit c99 compiler option
# - https://github.com/numpy/numpy/pull/12783/files
ENV CFLAGS='-std=c99'

RUN curl -s -L -o miniconda_installer.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
RUN bash miniconda_installer.sh -b -f -p /opt/conda && \
    source /opt/conda/etc/profile.d/conda.sh && \
    conda update -n base -c defaults conda && \
    conda clean -a -y -q

# check that miniconda3 has provided the global conda init for bash
RUN if ! test -f /etc/profile.d/conda.sh; then \
        mkdir -p /etc/profile.d && \
        ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh; \
    fi

ENV GEO_PATH=/opt/geo_env

RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda create -y -p ${GEO_PATH} python=${PY_VERSION} && \
    conda activate ${GEO_PATH} && \
    conda config --env --add channels conda-forge && \
    conda config --env --set channel_priority strict

RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate ${GEO_PATH} && \
    conda install -y python=${PY_VERSION} geopandas && \
    conda clean -a -y -q

# only for python 3.6; use built-in dataclasses for 3.7+
RUN source /opt/conda/etc/profile.d/conda.sh && \
    conda activate ${GEO_PATH} && \
    if python --version | grep 'Python 3.6'; then pip install -U dataclasses; fi

# (/opt/geo_env) bash-4.2# du -sh /opt/geo_env/lib/python3.6/site-packages
# 101M	/opt/geo_env/lib/python3.6/site-packages

ENV PYTHONPATH=${GEO_PATH}/lib/python${PY_VERSION}/site-packages:${PYTHONPATH}
ENV PATH=${GEO_PATH}/bin:${PATH}

CMD ['/bin/bash']

