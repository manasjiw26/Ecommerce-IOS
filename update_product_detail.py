import re

file_path = "IOS/Ecommerce/Ecommerce/Views/ProductDetailView.swift"

with open(file_path, "r") as f:
    lines = f.readlines()

vars = [
    "similarProducts", "isLoadingSimilar", "productReviews", "isLoadingReviews",
    "isShowingWriteReviewSheet", "isShowingGuestAlert", "isReviewsExpanded",
    "isShowingRegistrySheet", "showingToast", "toastMessage", "averageRating",
    "sortedReviews"
]

funcs = [
    "fetchSimilarProducts", "fetchReviews", "submitReview", "showToast"
]

out_lines = []
for i, line in enumerate(lines):
    # Only modify within the main ProductDetailView struct body
    if i < 678:
        for v in vars:
            # Replace $var with $viewModel.var
            line = re.sub(rf'\${v}\b', f'$viewModel.{v}', line)
            # Replace raw var with viewModel.var (avoiding dot prefix)
            line = re.sub(rf'(?<!\.)(?<!viewModel\.)\b{v}\b', f'viewModel.{v}', line)
            
        for f_name in funcs:
            line = re.sub(rf'(?<!\.)(?<!viewModel\.)\b{f_name}\b', f'viewModel.{f_name}', line)
            
        # Custom replaces for functions with different signatures or specific patterns
        line = re.sub(r'(?<!\.)(?<!viewModel\.)\bpercentage\(', r'viewModel.percentage(', line)
        line = re.sub(r'(?<!\.)(?<!viewModel\.)\bshareProduct\(\)', r'viewModel.shareProduct(sourceView: nil)', line)
            
    out_lines.append(line)

with open(file_path, "w") as f:
    f.writelines(out_lines)

print("Updated ProductDetailView bindings successfully.")
