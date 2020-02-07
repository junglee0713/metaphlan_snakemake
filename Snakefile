###
# Run under 'source activate metaphlan'
# Adated from Jesse's sbx_metaphlan
###

import os
import pandas

PROJECT_DIR = config['PROJECT_DIR']
DECONTAM_DIR = PROJECT_DIR + '/sunbeam_output/qc/decontam'
CLASSIFY_FP = PROJECT_DIR + '/sunbeam_output/classify'
SAMPLES_FP = PROJECT_DIR + '/samples.csv'

SAMPLES = []
with open(SAMPLES_FP) as f:
    lines = f.readlines()

for line in lines:
    SAMPLES.append(line.split(',')[0])

workdir: PROJECT_DIR

rule all:
    input:
        CLASSIFY_FP + '/metaphlan/taxonomic_assignments.tsv'

# An all-samples-in-one summary table, with samples on columns and taxa on
# rows.
rule taxonomic_assignment_report:
    input:
        expand(CLASSIFY_FP + '/metaphlan/review/{sample}_review.txt',
                sample = SAMPLES)
    output:
        CLASSIFY_FP + '/metaphlan/taxonomic_assignments.tsv'
    run:
        metaphlan_make_report(input, output[0])

# Chunyu's curated version of the metaphlan output file.
rule metaphlan_review_output:
    input:
        CLASSIFY_FP + '/metaphlan/raw/{sample}_metagenome.txt'
    output:
        CLASSIFY_FP + '/metaphlan/review/{sample}_review.txt'
    run:
        review_output(input[0], output[0])

# metaphlan_classify does not work
# under snakemake
# had to do it manually
# couldn't figure out why at this point :(
rule metaphlan_classify:
    input: 
        CLASSIFY_FP + '/metaphlan/raw/{sample}.bowtie2.sam.bz2'
    output:
        CLASSIFY_FP + '/metaphlan/raw/{sample}_metagenome.txt'
    params:
        config['METAPHLAN_DB']
    threads:
        config['THREADS']
    shell:
        """
            metaphlan2.py \
            --nproc {threads} \
            --input_type sam \
            --nreads 100 \
            --bowtie2db {params} \ 
            {input} {output}
        """

rule metaphlan_bowtie:
    input:
        expand(DECONTAM_DIR + '/{{sample}}_{rp}.fastq.gz', rp = ['1', '2'])
    params:
        config['METAPHLAN_DB'] + '/' + config['BOWTIE2_INDEX']
    output:
        sambz2 = CLASSIFY_FP + '/metaphlan/raw/{sample}.bowtie2.sam.bz2'
    threads:
        config['THREADS']
    shell:
        """
            bowtie2 --sam-no-hd --sam-no-sq --no-unal --very-sensitive \
            -x {params} \
            -1 {input[0]} -2 {input[1]} -p {threads} \
            | bzip2 > {output.sambz2}
        """

onsuccess:
    print('Workflow finished, no error')
    shell('mail -s "Workflow finished successfully" ' + config['ADMIN_EMAIL'] + ' < {log}')

onerror:
    print('An error occurred')
    shell('mail -s "An error occurred" ' + config['ADMIN_EMAIL'] + ' < {log}')

###
# helper functions,
# adated from Chunyu's functions
###

def metaphlan_make_report(fps_input, fp_output):
    kos = []
    for fp in fps_input:
        # filter out the files that don't have any results
        if os.path.getsize(fp) > 1:
            # build pandas dataframes for each file of results
            kos.append(parse_results(fp,"_review.txt"))
    # merge the column results
    kos = pandas.concat(kos, axis=1)

    # write them to file. Replace NAs (due to merging) with 0.
    kos.to_csv(fp_output, sep='\t', na_rep=0, index_label="Term")

def parse_results(fp, input_suffix):
    """ Return a DataFrame containing the results of one sample"""
    sample_name = os.path.basename(fp).rsplit(input_suffix)[0]
    DF_col3 = pandas.read_csv(fp, sep='\t', index_col=0, names=["NCBI_tax_id", sample_name], skiprows=1)
    DF_col2 = DF_col3[[sample_name]]
    return DF_col2

###
# Chunyu's function to filter to just species-level classifications, 
# excluding strain-level.
###

def review_output(raw_fp, output_fp):
     with open(raw_fp) as f:
        output_lines = f.read().splitlines(True)
        
        if len(output_lines) < 5:
            raise ValueError("Metaphlan output has fewer than 5 lines.")
        else:
            del output_lines[0:3]
            header = output_lines.pop(0)
            revised_output_lines = [header]
            for line in output_lines:
                if "s__" in line:
                    revised_output_lines.append(line)
            revised_output_lines = "".join(revised_output_lines)
        
        with open(output_fp, 'w') as f:
            f.write(revised_output_lines)
