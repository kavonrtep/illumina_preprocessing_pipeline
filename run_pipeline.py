#!/usr/bin/env python
""" this script take as argument config.yaml file and run snakemake pipeline """

import argparse
import os
import subprocess
import yaml

def show_singularity_settings(config_object):
    # get absolute paths and show singularity --bind options
    paths = [os.path.abspath(config_object['output_dir'])]
    # read csv input table and get paths for individual fastq files (column 1 and 2)
    with open(config_object['input_table'], 'r') as file:
        for line in file:
            items = line.strip().split("\t")
            # get directory name of the file
            paths.append(os.path.dirname(items[0]))
            paths.append(os.path.dirname(items[1]))
    # get unique directories
    dirs = set(paths)
    bind_string = " ".join([F"-B {d}" for d in dirs])
    print("Run singularity with following bind options:")
    print(F"singularity run {bind_string} ....")


def check_all_fastq_paths(config_object):
    # read csv input table and get paths for individual fastq files (column 1 and 2)
    fastq_files = []
    with open(config_object['input_table'], 'r') as file:
        for line in file:
            items = line.strip().split("\t")
            # get directory name of the file
            fastq_files.append(items[0])
            fastq_files.append(items[1])
    # check if dir and files exist
    for f in fastq_files:
        if not os.path.exists(f):
            print(F"File {f} does not exist or is not accessible")
            show_singularity_settings(config_object)
            exit(1)


def main():
    # get arguments

    config_template="/opt/pipeline/config.yaml"
    # read config file, keep end of lines
    config_string = open(config_template, 'r').read()
    parser = argparse.ArgumentParser(
            description=
"""Analysis of ChIP seq using bamCompare, epic2 and macs3 programs. 
Analysis is exected as snakemake pipeline. Configuragion is provided in
config.yaml file. """,
            epilog=F"""Example of config.yaml file:
            
{config_string}

            """,
            formatter_class=argparse.RawDescriptionHelpFormatter
        )
    parser.add_argument('-c', '--config', required=True, help='config file')
    parser.add_argument('-t', '--threads', required=False, default=2, type=int,
                        help='Number of threads to use')
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.realpath(__file__))
    snakefile="/opt/pipeline/snakefile"
    # create output directory if it does not exist

    # get conda prefix
    CONDA_ENVS_PATH = os.environ.get('CONDA_ENVS_PATH')
    # NOTE - snake make is using --conda-prefix as path to conda envs while conda
    # CONDA_PREFIX variable points to conda installation directory!
    # run snakemake

    # for subprocess we need to set XDG_CACHE_HOME otherwise snakemake will use
    # non-writable directory
    # load yaml file from args.config
    try:
        config_object = yaml.safe_load(open(args.config))
    except FileNotFoundError:
        # the path is either wrong or path is not mounted
        print(F"Cannot open config file {args.config}")
        print(F"Check if the file exists and is accessible or if the path is mounted "
              F"using -B option in singularity run command")
        exit(1)

    output_dir = config_object['output_dir']

    # this could be relative path, so we need to get absolute path
    output_dir = os.path.abspath(output_dir)
    cache_dir = F"{output_dir}/.cache"
    # check if output_dir exists or can be created (dry-run creates directory)
    try:
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
    except PermissionError:
        print(F"Cannot create output directory {output_dir}")
        show_singularity_settings(config_object)
        exit(1)

    # check if fastq files are accessible
    check_all_fastq_paths(config_object) # exit if not accessible

    cmd = (F"snakemake --snakefile {script_dir}/Snakefile --configfile {args.config} "
           F"--cores {args.threads} --use-conda --conda-prefix {CONDA_ENVS_PATH} "
           F"--conda-frontend mamba --show-failed-logs")

    # append cache dir to other environment variables
    env = os.environ.copy()
    env['XDG_CACHE_HOME'] = cache_dir
    subprocess.check_call(cmd, shell=True, env=env)

if __name__ == "__main__":
    main()
