# Illumina preprocessing pipeline


## Requirements 
Singularity is required to use the container. Singularity can be installed using conda environment. 

```bash
conda create -n singularity3 -c conda-forge "singularity>=3.6"
conda activate singularity3
```

## Quick Start
Singularity image (.sif file) can be downloaded from https://github.com/kavonrtep/illumina_preprocessing_pipeline/releases

Format of config.yaml file is as follows:

```yaml
input_table: data/input_files.csv
output_dir: output
```
File with `input_table` is tab delimited file with following columns:
1. Path to forward reads FASTQ
2. Path to reverse reads FASTQ
3. Prefix used for output files

Example of input_table:

|                                                  |                                                   ||
|--------------------------------------------------|---------------------------------------------------|-|
| /mnt/data/18036D-07-01_S152_L004_R1_001.fastq.gz | 	/mnt/data/18036D-07-01_S152_L004_R2_001.fastq.gz |	Prefix1|
| /mnt/18036D-07-02_S153_L004_R1_001.fastq.gz      | 	/mnt/data/18036D-07-02_S153_L004_R2_001.fastq.gz |	Prefix2|
| data/18036D-07-03_S154_L004_R1_001.fastq.gz      | 	/mnt/data/18036D-07-03_S154_L004_R2_001.fastq.gz |	Prefix3|


To run the pipeline, execute the following command:

```bash
singularity run -B /path/to/ -B $PWD illumina_preprocessing_pipeline.sif -c config.yaml -t 20
````
Parameter `-t` specifies the number of threads to use. Singularity parameter `-B` is used to bind the input and output directories to the container. Without this parameter, the container will not be able to access the input and output files. File `config.yaml` must be also in directory which is accessible to the container. In the example above this is the current directory `$PWD`. 


## Output structure

```bash
.
├── adapter_trimming      # FASTQ files from 1st step of preprocessing
│   └── fastqc            # FastQC report on adapter trimmed FASTQ files
├── quality_and_trim      # FASTQ files from 2nd step of preprocessing
│   └── fastqc            # FastQC report on quality trimmed FASTQ files
├── original_fastqc       # FastQC report on original FASTQ files
├── multiqc_data          # MultiQC data directory 
└── multiqc_report.html   # MultiQC report on all FASTQ files

```


## Build the container

To build the container, run the following command:

```bash
SINGULARITY=`which singularity`
sudo $SINGULARITY build illumina_preprocessing_pipeline_0.1.1.sif Singularity
```