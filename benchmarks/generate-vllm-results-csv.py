import os
import glob
import json
import csv

# Define the base directory path to match JSON files
#endpoint = 'llm.lws.nkp'
#endpoint = 'llm.vllm.nkp'
#endpoint = 'nai.cnai.nai-nkp-mgx'
endpoint = '*'
base_directory_path = 'vllm-benchmark-results/' + endpoint + '/*'
file_pattern = '*_results.json'
search_pattern = os.path.join(base_directory_path, '**', file_pattern)

# Initialize a list to store the rows for the CSV file
rows = []
headers = set()

# Iterate over each JSON file in all subdirectories
for file_path in glob.glob(search_pattern, recursive=True):
    with open(file_path, 'r') as file:
        data = json.load(file)
        row = {}
        for key, value in data.items():
            if isinstance(value, (str, int, float, bool)):
                row[key] = value
                headers.add(key)
        rows.append(row)

# Filter out unwanted columns
filtered_headers = {header for header in headers if header not in [
    'use_beam_search', 'backend', 'config:serving-model-name', 'config:url', 'config:endpoint-replicas', 'best_of', 'num_prompts',
    'config:gpu-model.1', 'config:tensor-parallel-size.1', 'config:vllm-version.1', 'config:pipeline-parallel-size.1', 'config:tokenizer'
] and not header.endswith('.1')}

# Sort and group columns
sorted_headers = sorted(filtered_headers)
priority_headers = ['date', 'model_id', 'tokenizer_id', 'config:gpu-model', 'config:tensor-parallel-size', 'config:pipeline-parallel-size', 'config:vllm-version', 'use-case:type', 'use-case:isl', 'use-case:osl', 'use-case:num-of-prompts', 'request_rate']
date_model_headers = [header for header in priority_headers if header in sorted_headers]
use_case_headers = [header for header in sorted_headers if header.startswith('use_case:') and header not in priority_headers]
config_headers = [header for header in sorted_headers if header.startswith('config:') and header not in ['config:serving-model-name', 'config:url', 'config:endpoint-replicas'] and not header.endswith('.1')]
# Ensure config:pipeline-parallel-size is after config:tensor-parallel-size
if 'config:tensor-parallel-size' in config_headers and 'config:pipeline-parallel-size' in config_headers:
    config_headers.remove('config:pipeline-parallel-size')
    index = config_headers.index('config:tensor-parallel-size')
    config_headers.insert(index + 1, 'config:pipeline-parallel-size')
ttft_headers = [header for header in sorted_headers if '_ttft_' in header]
itl_headers = [header for header in sorted_headers if '_itl_' in header]
tpot_headers = [header for header in sorted_headers if '_tpot_' in header]
e2el_headers = [header for header in sorted_headers if '_e2el_' in header]
other_headers = [header for header in sorted_headers if header not in priority_headers and not header.startswith('use_case:') and not header.startswith('config:') and '_ttft_' not in header and '_itl_' not in header and '_tpot_' not in header and '_e2el_' not in header]

grouped_headers = date_model_headers + config_headers + use_case_headers + ttft_headers + itl_headers + tpot_headers + e2el_headers + other_headers

# Move 'request_rate' after 'use-case:num-of-prompts'
if 'request_rate' in grouped_headers:
    grouped_headers.remove('request_rate')
    use_case_num_of_prompts_index = grouped_headers.index('use-case:num-of-prompts')
    grouped_headers.insert(use_case_num_of_prompts_index + 1, 'request_rate')

# Move all columns starting at 'completed' next to 'request_rate'
if 'completed' in grouped_headers:
    completed_index = grouped_headers.index('completed')
    completed_headers = grouped_headers[completed_index:]
    grouped_headers = grouped_headers[:completed_index]
    request_rate_index = grouped_headers.index('request_rate')
    grouped_headers = grouped_headers[:request_rate_index + 1] + completed_headers + grouped_headers[request_rate_index + 1:]

# Remove any remaining columns that end with '.1'
grouped_headers = [header for header in grouped_headers if not header.endswith('.1')]

# Sort rows by 'request_rate'
rows.sort(key=lambda x: x.get('use-case:type', 0))

# Write the list of rows to a CSV file
csv_file_path = 'output_reordered_filtered.csv'
with open(csv_file_path, 'w', newline='') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=grouped_headers)
    writer.writeheader()
    for row in rows:
        filtered_row = {key: value for key, value in row.items() if key in grouped_headers}
        writer.writerow(filtered_row)

print(f"Re-ordered, filtered, and sorted CSV file has been created at {csv_file_path}")