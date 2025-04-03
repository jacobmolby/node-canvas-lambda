FROM amd64/amazonlinux:2023

ARG OUT=/root/layers
ARG NODE_VERSION=22

# set up container
RUN yum -y update 
RUN yum -y groupinstall "Development Tools" 


RUN curl --silent --location https://unofficial-builds.nodejs.org/download/release/v22.14.0/node-v22.14.0-linux-x64-glibc-217.tar.gz -o node-v22.14.0-linux-x64-glibc-217.tar.gz \
	&& tar -xvf node-v22.14.0-linux-x64-glibc-217.tar.gz \
	&& mv node-v22.14.0-linux-x64-glibc-217 /usr/local/nodejs \
	&& ln -s /usr/local/nodejs/bin/node /usr/local/bin/node \
	&& ln -s /usr/local/nodejs/bin/npm /usr/local/bin/npm

RUN yum install -y \
	which \
	binutils \
	sed \
	gcc-c++ \
	cairo-devel \
	libjpeg-turbo-devel \
	pango-devel \
	giflib-devel \
	pixman-devel \
	librsvg2-devel


# will be created and become working dir
WORKDIR $OUT/nodejs

RUN npm install --build-from-source canvas@3.1.0

# will be created and become working dir
WORKDIR $OUT/lib

# gather missing libraries
RUN curl https://raw.githubusercontent.com/ncopa/lddtree/v1.26/lddtree.sh -o $OUT/lddtree.sh \
	&& chmod +x $OUT/lddtree.sh \
	&& cp $($OUT/lddtree.sh -l $OUT/nodejs/node_modules/canvas/build/Release/canvas.node | grep '^\/lib' | sed -r -e '/canvas.node$/d') .

# Create fonts directory and copy necessary files
WORKDIR $OUT/fonts

COPY fonts/* .
RUN mkdir -p $OUT/fonts-cache


WORKDIR $OUT

# Instead of creating two separate zip files, create one combined zip file
# Create a combined zip file containing the nodejs, lib, and fontconfig directories
# The -r flag makes the zip operation recursive
# The -9 flag sets the compression level to maximum (9)
# The resulting zip file is named based on the NODE_VERSION environment variable
RUN zip -r -9 node${NODE_VERSION}_canvas_combined_layer.zip nodejs lib fonts fonts-cache 