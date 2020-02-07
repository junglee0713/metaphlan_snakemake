#!/bin/bash

snakemake -j 300 \
	--configfile /home/leej39/metaphlan_snakemake/config.yml \
	--cluster-config /home/leej39/metaphlan_snakemake/cluster.json \
	-w 180 \
	--notemp \
	-p \
	-c \
	"qsub -cwd -r n -V -l h_vmem={cluster.h_vmem} -l mem_free={cluster.mem_free} -pe smp {threads}" \
    -n
