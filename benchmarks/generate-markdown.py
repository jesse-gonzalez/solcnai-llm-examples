import os

# Directory to scan
base_directory = 'genai-perf-results'

# Output Markdown file
output_file = 'genai-perf-results-plots-summary.md'

# List of plot file extensions
plot_extensions = ['.png', '.jpg', '.jpeg', '.svg']

# Scan the base directory for *-compare directories
compare_directories = [d for d in os.listdir(base_directory) if os.path.isdir(os.path.join(base_directory, d)) and d.endswith('-compare')]

# Generate Markdown content
markdown_content = "# GenAI Perf Results Summary\n\n"

for compare_dir in compare_directories:
    markdown_content += f"## {compare_dir}\n\n"
    compare_dir_path = os.path.join(base_directory, compare_dir)
    plot_files = [f for f in os.listdir(compare_dir_path) if os.path.splitext(f)[1] in plot_extensions and 'token-to-token latency' not in f]
    for plot_file in plot_files:
        markdown_content += f"![{plot_file}]({compare_dir_path}/{plot_file})\n\n"

# Write to the Markdown file
with open(output_file, 'w') as f:
    f.write(markdown_content)

print(f"Markdown file '{output_file}' generated successfully.")