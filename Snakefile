# Run under 'source activate metaphlan'
import os

PROJECT_DIR = config["PROJECT_DIR"]
CLASSIFY_FP = PROJECT_DIR + "/sunbeam_output/classify"
SAMPLES_FP = PROJECT_DIR + "/samples.csv"

SAMPLES = []
with open(SAMPLES_FP) as f:
    lines = f.readlines()

for line in lines:
    SAMPLES.append(line.split(',')[0])

workdir: PROJECT_DIR

os.system("source activate metaphlan")

rule all:
    input:
        expand(CLASSIFY_FP + "/metaphlan/raw/{sample}_metagenome.txt",
                sample = SAMPLES)

rule metaphlan_classify:
    input: 
        sambz2 = CLASSIFY_FP + "/metaphlan/raw/{sample}.bowtie2.sam.bz2"
    output:
        meta_raw = CLASSIFY_FP + "/metaphlan/raw/{sample}_metagenome.txt"
    params:
        metaphlan_db = config["METAPHLAN_DB"]
    threads:
        config["THREADS"]
    shell:
        """
            which metaphlan2.py

            metaphlan2.py  \
            --nproc {threads} \
            --input_type sam \
            --nreads 100 \
            --bowtie2db {params.metaphlan_db} \ 
            {input.sambz2} {output.meta_raw}
        """

onsuccess:
    print("Workflow finished, no error")
    shell("mail -s 'Workflow finished successfully' " + config["ADMIN_EMAIL"] + " < {log}")

onerror:
    print("An error occurred")
    shell("mail -s 'An error occurred' " + config["ADMIN_EMAIL"] + " < {log}")
