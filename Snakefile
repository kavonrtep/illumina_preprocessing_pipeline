import os
def get_jobs(input_table):
  jobs = []
  with open(input_table, "r") as file:
    for line in file:
      parts = line.strip().split()
      if len(parts) == 3:
        file1, file2, output_prefix = parts
        jobs.append((file1, file2, output_prefix))
    return jobs

def create_dirs(*dirs):
    for d in dirs:
        if not os.path.exists(d):
            os.makedirs(d)

subdirs = [config['output_dir']+"/"+i for i in ["adapter_trimming/fastqc",
                                                "quality_and_trim/fastqc",
                                                "original_fastqc"]]
# create output directories
create_dirs(*subdirs)

number_of_jobs = len(get_jobs(config['input_table']))
print(f"Number of jobs: {number_of_jobs}")
number_of_cores = workflow.cores
print(f"Number of cores: {number_of_cores}")
n_cores_per_job = int(number_of_cores/number_of_jobs)
if n_cores_per_job < 1:
    n_cores_per_job = 1
print(f"Number of cores per job: {n_cores_per_job}")



rule all:
    input:
        expand("{output_dir}/quality_and_trim/{prefix}_prep.fastq.gz",
               output_dir=config['output_dir'],
               prefix=[job[2] for job in get_jobs(config['input_table'])]),
        expand("{output_dir}/quality_and_trim/.{prefix}_fastqc.done",
               output_dir=config['output_dir'],
               prefix=[job[2] for job in get_jobs(config['input_table'])]),
        f"{config['output_dir']}/multiqc_report.html"





rule trimmomatic:
    input:
        forward_fastq=lambda wildcards: [job[0] for job in get_jobs(config['input_table']) if job[2] == wildcards.prefix][0],
        reverse_fastq=lambda wildcards: [job[1] for job in get_jobs(config['input_table']) if job[2] == wildcards.prefix][0]
    output:
        p1="{output_dir}/adapter_trimming/{prefix}_adapt_trim_1P.fastq.gz",
        p2="{output_dir}/adapter_trimming/{prefix}_adapt_trim_2P.fastq.gz",
        s1="{output_dir}/adapter_trimming/{prefix}_adapt_trim_1U.fastq.gz",
        s2="{output_dir}/adapter_trimming/{prefix}_adapt_trim_2U.fastq.gz",
        p1p="{output_dir}/quality_and_trim/{prefix}_prep.fastq.gz",
    params:
        base="{output_dir}/adapter_trimming/{prefix}_adapt_trim.fastq.gz",
        output_dir=config['output_dir']
    conda:
        "envs/trimmomatic.yaml"
    threads: n_cores_per_job
    shell:
        """
        echo {input}
        echo "Processing {input.forward_fastq} and {input.reverse_fastq}"
        which trimmomatic
        PATH_TO_ADAPTERS=$(dirname $(which trimmomatic))/../share/trimmomatic/adapters/TruSeq3-PE.fa
        echo "-------------------"
        echo "Using adapters from $PATH_TO_ADAPTERS"
        ls -l $PATH_TO_ADAPTERS
        trimmomatic PE -threads {threads} {input.forward_fastq} {input.reverse_fastq} -baseout {params.base} ILLUMINACLIP:$PATH_TO_ADAPTERS:2:30:10:8:true MINLEN:20
        trimmomatic SE -threads {threads} {output.p1} {output.p1p} HEADCROP:9 MAXINFO:100:0.8 CROP:100 MINLEN:100
        """


# run fastqc on all inputs and outputs

rule fastqc:
    input:
        forward_fastq=lambda wildcards: [job[0] for job in get_jobs(config['input_table']) if job[2] == wildcards.prefix][0],
        reverse_fastq=lambda wildcards: [job[1] for job in get_jobs(config['input_table']) if job[2] == wildcards.prefix][0],
        p1="{output_dir}/adapter_trimming/{prefix}_adapt_trim_1P.fastq.gz",
        p2="{output_dir}/adapter_trimming/{prefix}_adapt_trim_2P.fastq.gz",
        s1="{output_dir}/adapter_trimming/{prefix}_adapt_trim_1U.fastq.gz",
        s2="{output_dir}/adapter_trimming/{prefix}_adapt_trim_2U.fastq.gz",
        p1p="{output_dir}/quality_and_trim/{prefix}_prep.fastq.gz"
    output:
        qc1="{output_dir}/adapter_trimming/fastqc/{prefix}_adapt_trim_1P_fastqc.html",
        qc2="{output_dir}/quality_and_trim/fastqc/{prefix}_prep_fastqc.html",
        fastqc_done="{output_dir}/quality_and_trim/.{prefix}_fastqc.done"

    params:
        qc_ori_dir=directory("{output_dir}/original_fastqc/"),
        output_dir=config['output_dir']
    conda:
        "envs/fastqc.yaml"
    threads: n_cores_per_job
    shell:
        """
        echo "_________________________________________________________________"
        echo "Running fastqc on {input.forward_fastq} and {input.reverse_fastq}"
        dir1=$(dirname {input.p1})
        dir1out=$(dirname {output.qc1})
        dir2=$(dirname {input.p1p})
        dir2out=$(dirname {output.qc2})
        fastqc $dir1/*.fastq.gz -o $dir1out -c {threads}
        fastqc $dir2/*.fastq.gz -o $dir2out -c {threads}
        fastqc {input.forward_fastq} {input.reverse_fastq} -o {params.qc_ori_dir} -c {threads}
        wait
        touch {output.fastqc_done}
        """




rule multiqc:
    input:
       expand("{output_dir}/quality_and_trim/.{prefix}_fastqc.done",
           output_dir=config['output_dir'],
           prefix=[job[2] for job in get_jobs(config['input_table'])])
    output:
       f"{config['output_dir']}/multiqc_report.html"
    params:
         output_dir=config['output_dir']
    conda:
        "envs/multiqc.yaml"
    threads: workflow.cores
    shell:
       """
       cd {params.output_dir}
       multiqc --dirs --fullnames -f .
       """

