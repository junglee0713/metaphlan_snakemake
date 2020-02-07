#!/bin/bash

snakemake -j 300 \
	--configfile /home/leej39/metaphlan_snakemake/config.yml \
	--cluster-config /home/leej39/metaphlan_snakemake/cluster.json \
	-w 180 \
	--notemp \
	-p \
	-c \
	"qsub -cwd -r n -V -l h_vmem={cluster.h_vmem} -l mem_free={cluster.mem_free} -pe smp {threads}" \
    --cleanup-metadata /scr1/users/leej39/Greg_Tasian_New/sunbeam_output/classify/metaphlan/raw/s.682947.bowtie2.sam.bz2
