#!/bin/bash
cat <<'EOF'
============================================================
Readstocount RNA-seq Pipeline

Author: Jaidev Sharma
GitHub: https://github.com/jaidev233/Readstocount-RNA-seq-pipeline

License: GNU General Public License v3.0 (GPL-3.0)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.
============================================================
EOF

echo "NOTE: Default index/GTF paths assume files are present in the working directory."

#========================================================================
# edit below the absolute paths
#========================================================================
# Predefined default paths for each organism
default_human_index="./"
default_rattus_index="./"
default_mus_index="./"
default_drosophila_index="./"
default_celegans_index="./"
default_scer_index="./"

# Define default paths for each organism
default_human_gtf="./"
default_rattus_gtf="./"
default_mus_gtf="./"
default_drosophila_gtf="./"
default_celegans_gtf="./"
default_scerevisiae_gtf="./"
#========================================================================
# edit below the absolute paths
#========================================================================


# Time the script
start_time=$(date +%s)

echo '         ___'
echo '       _(((,|			How do I analyze RNA-seq data?'
echo '      /  _-\\'
echo '     / C o\o \'
echo '   _/_    __\ \     __ __     __ __     __ __     __'
echo '  /   \ \___/  )   /--X--\   /--X--\   /--X--\   /--/'
echo '  |    |\_|\  /   /--/ \--\ /--/ \--\ /--/ \--\ /--/'
echo '  |    |#  #|/          \__X__/   \__X__/   \__X__/'
echo '  (   /     |'
echo '   |  |#  # |'
echo '   |  |    #|'
echo '   |  | #___n_,_'
echo ',-/   7-'"'"' .     `\'
echo '`-\...\\-_   -  o /'
echo '   |#  # `---U--'
echo '   `-v-^-'"'"'/'
echo '     \  |_|_ Wny'
echo '     (___mnnm'

printf "\nWelcome to the RNA-seq analysis script!\n
This script will help you process and analyze your RNA-seq data.\n
Please make sure that you have the necessary software and dependencies installed before running this script.\n
1. fastp: (conda install -c bioconda fastp)\n
2. HISAT2: (conda install -c bioconda hisat2)\n
3. samtools: (conda install -c bioconda samtools)\n
4. trimmomatic: (conda install -c bioconda trimmomatic)\n
5. fastqc: (conda install -c bioconda fastqc)\n
6. featureCounts: (conda install -c bioconda subread)\n
7. multiqc: (conda install -c bioconda multiqc)\n
8. Anaconda or Miniconda (script install)\n
**** Stable internet connection to fetch required files and sufficient space and memory on your system\n
***** Fastq files are assumed to end with '_R1_001.fastq.gz' or '_R2_001.fastq.gz' to describe paired-end reads\n\n\n"

declare -a dependencies=("fastp" "trimmomatic" "hisat2" "samtools" "fastqc" "featureCounts" "multiqc")
missing_dependencies=()

# Function to install Conda
install_conda() {
    echo "Installing Miniconda..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    chmod +x miniconda.sh
    ./miniconda.sh -b -p "$HOME/miniconda"
    export PATH="$HOME/miniconda/bin:$PATH"
    rm miniconda.sh
    echo "Miniconda installed successfully."
}

# Check for Conda
if ! command -v conda >/dev/null 2>&1; then
    missing_dependencies+=("conda")
fi

# Prompt the user to install Conda
if [[ " ${missing_dependencies[*]} " =~ " conda " ]]; then
    read -p "Conda is not installed. Do you want to install Conda? [y/n] " answer
    if [[ $answer = y ]]; then
        install_conda
    else
        echo "Please install Conda manually before proceeding."
        exit 1
    fi
fi

# Check for other dependencies
for dependency in "${dependencies[@]}"; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        missing_dependencies+=("$dependency")
    fi
done

# Prompt the user to install missing dependencies
if [[ ${#missing_dependencies[@]} -gt 0 ]]; then
    echo "The following dependencies are missing: ${missing_dependencies[*]}"
    read -p "Do you want to install the missing dependencies? [y/n] " answer

    if [[ $answer = y ]]; then
        for dependency in "${missing_dependencies[@]}"; do
            case $dependency in
            "fastp")
                conda install -y -c bioconda fastp
                ;;
            "hisat2")
                conda install -y -c bioconda hisat2
                ;;
            "samtools")
                conda install -y -c bioconda samtools
                ;;
            "trimmomatic")
                conda install -y -c bioconda trimmomatic
                ;;
            "fastqc")
                conda install -y -c bioconda fastqc
                ;;
            "featureCounts")
                conda install -y -c bioconda subread
                ;;
            "multiqc")
                conda install -y -c bioconda multiqc
                ;;
            "conda")
                echo "Conda is not installed. Please install Conda manually."
                ;;
            esac
        done
        echo "Dependencies installed successfully!"
    else
        echo "Please install the missing dependencies manually before running the script."
        exit 1
    fi
else
    echo "All dependencies are installed."
fi

# Store the current working directory path
working_dir=$(realpath "$(pwd)")
echo "Working Directory: $working_dir"

# Initialize processed files directory (will be updated based on user choices)
processed_files_dir="$working_dir"

# Prompt the user for the number of threads
echo "Enter the number of threads:"
read num_threads

# Check if the input is a valid positive integer
if ! [[ "$num_threads" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid input. Please enter a positive integer."
    exit 1
fi

echo "Running with $num_threads threads..."

# Ask user to select organism
printf "Select the organism for which to download the genome indices:\n 1. Rattus norvegicus\n 2. Homo sapiens (default)\n 3. Mus musculus\n 4. Drosophila melanogaster\n 5. C. elegans\n 6. S. cerevisiae\n"
read -p "Enter your choice (1-6, default is 2): " user_input
user_input=${user_input:-2}


# Set default paths based on organism selection
case $user_input in
    1)
        default_index="$default_rattus_index"
        default_gtf="$default_rattus_gtf"
        organism_name="Rattus norvegicus"
        ;;
    2)
        default_index="$default_human_index"
        default_gtf="$default_human_gtf"
        organism_name="Homo sapiens"
        ;;
    3)
        default_index="$default_mus_index"
        default_gtf="$default_mus_gtf"
        organism_name="Mus musculus"
        ;;
    4)
        default_index="$default_drosophila_index"
        default_gtf="$default_drosophila_gtf"
        organism_name="Drosophila melanogaster"
        ;;
    5)
        default_index="$default_celegans_index"
        default_gtf="$default_celegans_gtf"
        organism_name="C. elegans"
        ;;
    6)
        default_index="$default_scer_index"
        default_gtf="$default_scerevisiae_gtf"
        organism_name="S. cerevisiae"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo "Selected organism: $organism_name"

# List fastq files
echo "FASTQ files in the working directory:"
ls *.fastq.gz 2>/dev/null || echo "No .fastq.gz files found!"

echo ""
echo "========================================================================"
echo "                    COLLECTING ALL USER INPUTS                          "
echo "========================================================================"
echo ""

# Question 1: Index choice
echo "Would you like to provide a pre-downloaded index path or download the index files?"
echo "1. Provide path to existing HISAT2 index"
echo "2. Download HISAT2 index files"
read -p "Enter your choice (default is 1): " choice
choice=${choice:-1}

if [ "$choice" == "1" ]; then
    read -p "Enter the absolute path to your HISAT2 index directory (default is $default_index): " user_provided_path
    
    if [ -z "$user_provided_path" ]; then
        path_index="$default_index"
        echo "Using default HISAT2 index path: $path_index"
    elif [ -d "$user_provided_path" ]; then
        path_index="$user_provided_path"
        echo "Using provided HISAT2 index path: $path_index"
    else
        echo "Error: Path does not exist or is not a directory. Exiting."
        exit 1
    fi
    will_download_index="no"
elif [ "$choice" == "2" ]; then
    echo "Will download HISAT2 index files during processing."
    path_index="<will be downloaded to: $working_dir/hisat2-index>"
    will_download_index="yes"
else
    echo "Error: Invalid choice. Please select a valid option."
    exit 1
fi

echo ""

# Question 2: GTF file choice
echo "Do you want to provide a custom path to the GTF file or download it?"
echo "1. Provide path to existing GTF file"
echo "2. Download GTF file"
read -p "Enter your choice (default is 1): " path_choice
path_choice=${path_choice:-1}

if [ "$path_choice" -eq 1 ]; then 
    read -p "Please provide the absolute path to your GTF file (default is $default_gtf): " user_provided_gtf
    if [ -z "$user_provided_gtf" ]; then
        path_gtf="$default_gtf"
        echo "Using default GTF file: $path_gtf"
    elif [ -f "$user_provided_gtf" ]; then
        path_gtf="$user_provided_gtf"
        echo "Using provided GTF file: $path_gtf"
    else
        echo "Error: GTF file does not exist"
        exit 1
    fi
    will_download_gtf="no"
else
    path_gtf="<will be downloaded to: $working_dir/genome_annotation>"
    will_download_gtf="yes"
    echo "Will download GTF file during processing."
fi

echo ""

# Question 3: FASTQ validation
read -p "Do you want to validate FASTQ file integrity? [y/n] (default is y): " validate_fastq
validate_fastq=${validate_fastq:-y}

echo ""

# Question 4: QC and trimming choice
read -p "Do you want to perform QC & trimming of the fastq files? [y/n] " do_qc_trimming

if [[ $do_qc_trimming = y ]]; then
    read -p "Please select the method for analysis: 1) fastp or 2) fastqc+trimmomatic? " method_choice
    
    if [[ $method_choice = 2 ]]; then
        read -p "Do you want to perform trimming using Trimmomatic? [y/n] " do_trimmomatic
    else
        do_trimmomatic="n"
    fi
else
    method_choice="0"
    do_trimmomatic="n"
fi

# Print final configuration
echo ""
echo "========================================================================"
echo "                      CONFIGURATION SUMMARY                             "
echo "========================================================================"
echo "Organism:           $organism_name"
echo "Number of threads:  $num_threads"
echo "Index path:         $path_index"
echo "GTF file:           $path_gtf"
echo "Working directory:  $working_dir"
echo "Validate FASTQ:     $([ "$validate_fastq" = "y" ] && echo "Yes" || echo "No")"
echo "QC/Trimming:        $([ "$do_qc_trimming" = "y" ] && echo "Yes" || echo "No")"
if [[ $do_qc_trimming = y ]]; then
    echo "Method:             $([ "$method_choice" = "1" ] && echo "fastp" || echo "fastqc+trimmomatic")"
    if [[ $method_choice = 2 ]]; then
        echo "Trimmomatic:        $([ "$do_trimmomatic" = "y" ] && echo "Yes" || echo "No")"
    fi
fi
echo "========================================================================"
echo ""
read -p "Press Enter to start the pipeline or Ctrl+C to cancel..."

# Validate FASTQ files (optional)
if [[ $validate_fastq = y ]]; then
    echo ""
    echo "Validating FASTQ files..."
    validation_failed=0
    
    for file in *.fastq.gz; do
        if [ -f "$file" ]; then
            echo -n "Checking $file... "
            if gunzip -t "$file" 2>/dev/null; then
                echo "✅ OK"
            else
                echo "❌ FAILED"
                validation_failed=1
            fi
        fi
    done
    
    if [ $validation_failed -eq 1 ]; then
        echo ""
        echo "❌ Some FASTQ files failed validation!"
        read -p "Do you want to continue anyway? [y/n] " continue_anyway
        if [[ $continue_anyway != y ]]; then
            echo "Pipeline aborted."
            exit 1
        fi
    else
        echo "✅ All FASTQ files validated successfully!"
    fi
else
    echo ""
    echo "⚠️  Skipping FASTQ validation..."
fi

# STEP 1: QC and trimming
echo ""
echo "***************************************************************************************************************************************************************"
printf "STEP 1: QC and trimming\n\nPerform QC and trimming on fastq files\n\n"

if [[ $do_qc_trimming = y ]]; then
    
    if [[ $method_choice = 1 ]]; then
        echo "Performing QC & trimming using fastp..."
        
        read_file1=($(ls -d *_R1_001.fastq.gz 2>/dev/null))
        read_file2=($(ls -d *_R2_001.fastq.gz 2>/dev/null))
        
        if [ ${#read_file1[@]} -eq 0 ]; then
            echo "❌ No R1 files found matching pattern *_R1_001.fastq.gz"
            exit 1
        fi
        
        echo "Trimmed files will be saved to processed_files and QC results to fastp_results"
        mkdir -p processed_files
        mkdir -p fastp_results
        
        for f in "${read_file1[@]}"; do
            f2=${f/R1_001.fastq.gz/R2_001.fastq.gz}
            f3=${f/R1_001.fastq.gz/R1_R2.fastq.gz}
            echo "Processing $f and $f2..."
            
            fastp -i "$f" -I "$f2" \
                  -o "processed_files/trimmed_${f}" \
                  -O "processed_files/trimmed_${f2}" \
                  -h "fastp_results/${f3}-fastp.html" \
                  -j "fastp_results/${f3}-fastp.json"
        done
        
        processed_files_dir="$working_dir/processed_files"
        echo "✅ QC and trimming completed using fastp!"
        echo "Processed files location: $processed_files_dir"
        ls "$processed_files_dir"
        
    elif [[ $method_choice = 2 ]]; then
        echo "Performing QC using fastqc..."
        
        mkdir -p processed_files
        mkdir -p fastqc_results
        
        fastqc *.fastq.gz -o fastqc_results -t "$num_threads"
        echo "✅ FastQC reports generated in fastqc_results/"
        
        if [[ $do_trimmomatic = y ]]; then
            echo "Downloading and setting up Trimmomatic..."
            if [ ! -d "Trimmomatic-0.39" ]; then
                wget http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/Trimmomatic-0.39.zip
                unzip Trimmomatic-0.39.zip
            fi
            
            read_file1=($(ls -d *_R1_001.fastq.gz 2>/dev/null))
            read_file2=($(ls -d *_R2_001.fastq.gz 2>/dev/null))
            
            if [ ${#read_file1[@]} -eq 0 ]; then
                echo "❌ No R1 files found matching pattern *_R1_001.fastq.gz"
                exit 1
            fi
            
            for f in "${read_file1[@]}"; do
                f2=${f/R1_001.fastq.gz/R2_001.fastq.gz}
                base=${f/_R1_001.fastq.gz/}
                
                echo "Trimming $f and $f2..."
                java -jar Trimmomatic-0.39/trimmomatic-0.39.jar PE -threads "$num_threads" \
                    "$f" "$f2" \
                    "processed_files/trimmed_${f}" "processed_files/unpaired_${f}" \
                    "processed_files/trimmed_${f2}" "processed_files/unpaired_${f2}" \
                    TRAILING:10 -phred33
            done
            
            processed_files_dir="$working_dir/processed_files"
            echo "✅ Trimming completed using Trimmomatic!"
            echo "Processed files location: $processed_files_dir"
        else
            echo "Skipping trimming. Using original files for alignment."
        fi
        
    else
        echo "Invalid input. Please select 1 for fastp or 2 for fastqc."
        exit 1
    fi
else
    echo "QC and trimming skipped. Using original files."
fi

# STEP 2: Run HISAT2
echo ""
echo "***************************************************************************************************************************************************************"
printf "STEP 2: Run HISAT2\n\nAlignment using HISAT2\n\n"

# Assign organism and download URL based on input
case $user_input in
    1) 
        organism="Rattus norvegicus" 
        download_url="https://genome-idx.s3.amazonaws.com/hisat/rn6_genome.tar.gz"
        ;;
    2|"")
        organism="Homo sapiens" 
        download_url="https://genome-idx.s3.amazonaws.com/hisat/grch38_genome.tar.gz"
        ;;
    3) 
        organism="Mus musculus" 
        download_url="https://cloud.biohpc.swmed.edu/index.php/s/grcm38/download"
        ;;
    4) 
        organism="Drosophila melanogaster" 
        download_url="https://genome-idx.s3.amazonaws.com/hisat/dm6.tar.gz"
        ;;
    5) 
        organism="C. elegans" 
        download_url="https://cloud.biohpc.swmed.edu/index.php/s/bbynxoY2TPpRNQb/download"
        ;;
    6) 
        organism="S. cerevisiae" 
        download_url="https://cloud.biohpc.swmed.edu/index.php/s/Gsq4goLW4TDAz4E/download"
        ;;
    *)
        echo "Invalid input! Defaulting to Homo sapiens."
        organism="Homo sapiens"
        download_url="https://genome-idx.s3.amazonaws.com/hisat/grch38_genome.tar.gz"
        ;;
esac

echo "Selected organism: $organism"

# Handle index download if user chose option 2
if [ "$will_download_index" == "yes" ]; then
    echo "Creating HISAT2 index directory..."
    mkdir -p "$working_dir/hisat2-index"
    cd "$working_dir/hisat2-index" || exit
    
    echo "Downloading index files for $organism..."
    wget "$download_url" -O genome_index.tar.gz
    tar -xvf genome_index.tar.gz
    
    # Get the extracted directory name
    extracted_dir=$(ls -d */ 2>/dev/null | head -n 1 | sed 's:/*$::')
    if [ -z "$extracted_dir" ]; then
        # If no directory was created, files are in current directory
        path_index="$(pwd)"
    else
        path_index="$(pwd)/${extracted_dir}"
    fi
    
    echo "Genome index downloaded and extracted to: $path_index"
    
    # Return to working directory
    cd "$working_dir" || exit
fi

echo "Genome index is set to: $path_index"

# Navigate to processed files directory for alignment
cd "$processed_files_dir" || exit
echo "Running alignment from directory: $(pwd)"

# Look for trimmed files first, then fall back to original files
if ls trimmed_*R1_001.fastq.gz 1> /dev/null 2>&1; then
    echo "Using trimmed files for alignment..."
    read_set1=($(ls -d trimmed_*R1_001.fastq.gz))
    read_set2=($(ls -d trimmed_*R2_001.fastq.gz))
elif ls *R1_001.fastq.gz 1> /dev/null 2>&1; then
    echo "Using original files for alignment..."
    read_set1=($(ls -d *R1_001.fastq.gz))
    read_set2=($(ls -d *R2_001.fastq.gz))
else
    echo "❌ No FASTQ files found for alignment!"
    exit 1
fi

# Run alignment
for a in "${read_set1[@]}"; do
    a2=${a/R1_001.fastq.gz/R2_001.fastq.gz}
    a3=${a/R1_001.fastq.gz/R1_R2}
    
    # Remove "trimmed_" prefix from output filename if present
    a3=${a3/trimmed_/}
    
    echo "Now processing: $a3"
    
    hisat2 -p "$num_threads" --dta -x "$path_index/genome" \
           -1 "$a" -2 "$a2" \
           -S "${a3}.sam" \
           --summary-file "${a3}.summary.txt"
    
    echo "Sorting and converting to BAM..."
    samtools sort "${a3}.sam" -o "${a3}.bam"
    
    echo "Removing ${a3}.sam to save space"
    rm "${a3}.sam"
    
    echo "✅ HISAT2 finished running for $a3!"
    echo "________________________________________________________________________________________________"
done

echo "✅ All alignments completed!"
echo "BAM files are in: $processed_files_dir"

# Return to working directory
cd "$working_dir" || exit

# STEP 3: Run featureCounts - Quantification
echo ""
echo "***************************************************************************************************************************************************************"
printf "STEP 3: Run featureCounts - Quantification\n\nGet Counts Matrix\n\n"

# Handle GTF file download if user chose option 2
if [ "$will_download_gtf" == "yes" ]; then
    mkdir -p "$working_dir/genome_annotation"
    cd "$working_dir/genome_annotation" || exit
    
    echo "Downloading GTF file for $organism_name..."
    
    case $user_input in
        1)
            wget https://ftp.ensembl.org/pub/release-108/gtf/rattus_norvegicus/Rattus_norvegicus.mRatBN7.2.108.chr.gtf.gz
            gunzip Rattus_norvegicus.mRatBN7.2.108.chr.gtf.gz
            gtf_file="Rattus_norvegicus.mRatBN7.2.108.chr.gtf"
            ;;
        2)
            wget https://ftp.ensembl.org/pub/release-108/gtf/homo_sapiens/Homo_sapiens.GRCh38.108.gtf.gz
            gunzip Homo_sapiens.GRCh38.108.gtf.gz
            gtf_file="Homo_sapiens.GRCh38.108.gtf"
            ;;
        3)
            wget https://ftp.ensembl.org/pub/release-109/gtf/mus_musculus/Mus_musculus.GRCm39.109.gtf.gz
            gunzip Mus_musculus.GRCm39.109.gtf.gz
            gtf_file="Mus_musculus.GRCm39.109.gtf"
            ;;
        4)
            wget https://ftp.ensembl.org/pub/release-109/gtf/drosophila_melanogaster/Drosophila_melanogaster.BDGP6.32.109.gtf.gz
            gunzip Drosophila_melanogaster.BDGP6.32.109.gtf.gz
            gtf_file="Drosophila_melanogaster.BDGP6.32.109.gtf"
            ;;
        5)
            wget https://ftp.ensembl.org/pub/release-109/gtf/caenorhabditis_elegans/Caenorhabditis_elegans.WBcel235.109.gtf.gz
            gunzip Caenorhabditis_elegans.WBcel235.109.gtf.gz
            gtf_file="Caenorhabditis_elegans.WBcel235.109.gtf"
            ;;
        6)
            wget https://ftp.ensembl.org/pub/release-109/gtf/saccharomyces_cerevisiae/Saccharomyces_cerevisiae.R64-1-1.109.gtf.gz
            gunzip Saccharomyces_cerevisiae.R64-1-1.109.gtf.gz
            gtf_file="Saccharomyces_cerevisiae.R64-1-1.109.gtf"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
    
    path_gtf="$(pwd)/${gtf_file}"
    echo "GTF file downloaded and extracted to: $path_gtf"
    
    # Return to working directory
    cd "$working_dir" || exit
fi

# Validate GTF file exists
if [ ! -f "$path_gtf" ]; then
    echo "❌ GTF file not found: $path_gtf"
    exit 1
fi

path_gtf=$(realpath "$path_gtf")
echo "Using GTF file: $path_gtf"

# Create quants folder in working directory
mkdir -p "$working_dir/quants"

# Detect folder containing BAM files
if compgen -G "$processed_files_dir/*.bam" > /dev/null; then
    bam_dir="$processed_files_dir"
    echo "✅ BAM files found in: $bam_dir"
else
    echo "❌ No BAM files found in '$processed_files_dir'"
    exit 1
fi

# Run featureCounts
echo "Running featureCounts..."
featureCounts -p -T "$num_threads" \
              -a "$path_gtf" \
              -o "$working_dir/quants/all-featurecounts.txt" \
              "$bam_dir"/*.bam

echo "✅ featureCounts completed!"
echo "Count matrix saved to: $working_dir/quants/all-featurecounts.txt"

# Run MultiQC
echo ""
echo "Generating MultiQC report..."
cd "$working_dir" || exit
multiqc . -o multiqc_report

# Calculate runtime
end_time=$(date +%s)
runtime=$((end_time - start_time))
hours=$((runtime / 3600))
minutes=$(((runtime % 3600) / 60))
seconds=$((runtime % 60))

echo ""
echo "========================================="
echo "Pipeline completed successfully!"
echo "========================================="
printf "Total runtime: %02d:%02d:%02d (HH:MM:SS)\n" $hours $minutes $seconds
echo "Results location: $working_dir"
echo "- Processed files: $processed_files_dir"
echo "- Count matrix: $working_dir/quants/"
echo "- MultiQC report: $working_dir/multiqc_report/"
echo "========================================="