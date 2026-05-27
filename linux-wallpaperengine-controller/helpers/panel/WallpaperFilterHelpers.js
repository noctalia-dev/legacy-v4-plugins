.pragma library

function filteredAndSortedWallpapers(items, options) {
  const sourceItems = Array.isArray(items) ? items.slice() : [];
  const filterOptions = options || ({});
  const query = String(filterOptions.query || "").trim().toLowerCase();
  const selectedType = String(filterOptions.selectedType || "all");
  const selectedResolution = String(filterOptions.selectedResolution || "all");
  const sortMode = String(filterOptions.sortMode || "name");
  const sortAscending = filterOptions.sortAscending !== false;
  const resolutionFilterKey = filterOptions.resolutionFilterKey;

  let output = sourceItems;

  if (selectedType !== "all") {
    output = output.filter(item => String(item.type || "unknown").toLowerCase() === selectedType);
  }

  if (selectedResolution !== "all" && resolutionFilterKey) {
    output = output.filter(item => resolutionFilterKey(item.resolution) === selectedResolution);
  }

  if (query.length > 0) {
    output = output.filter(item => {
      return String(item.name || "").toLowerCase().indexOf(query) >= 0
        || String(item.id || "").toLowerCase().indexOf(query) >= 0;
    });
  }

  if (sortMode === "date") {
    output.sort((a, b) => Number(a.mtime || 0) - Number(b.mtime || 0));
  } else if (sortMode === "size") {
    output.sort((a, b) => Number(a.bytes || 0) - Number(b.bytes || 0));
  } else if (sortMode === "recent") {
    output.sort((a, b) => Number(b.mtime || 0) - Number(a.mtime || 0));
  } else {
    output.sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
  }

  if (!sortAscending) {
    output.reverse();
  }

  return output;
}

function pagedWallpapers(items, currentPage, pageSize) {
  const sourceItems = Array.isArray(items) ? items : [];
  const safePageSize = Math.max(1, Number(pageSize) || 1);
  const totalPages = Math.max(1, Math.ceil(sourceItems.length / safePageSize));
  const nextPage = Math.max(0, Math.min(Number(currentPage) || 0, totalPages - 1));
  const startIndex = nextPage * safePageSize;

  return {
    page: nextPage,
    items: sourceItems.slice(startIndex, startIndex + safePageSize)
  };
}
