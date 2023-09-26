#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <string>

// Function to read a value from a sysfs file
int read_sysfs_value(const char *path, char *value, size_t value_size) {
  FILE *file = fopen(path, "r");
  if (!file) {
    fprintf(stderr, "Failed to open file: %s\n", path);
    return 1;
  }
  if (fgets(value, value_size, file) == NULL) {
    perror("Failed to read from file");
    fclose(file);
    return 1;
  }
  fclose(file);
  return 0;
}
int main(int argc, char *argv[]) {
  if (argc != 2) {
    fprintf(stderr, "Usage: %s <PCI Slot ID>\n", argv[0]);
    return 1;
  }
  char slot_id[13];  // Format: "0000:bb:dd.f"
  snprintf(slot_id, sizeof(slot_id), "%s", argv[1]);
  // Path to PCI-e generation and lane count information
  char path[256];
  snprintf(path, sizeof(path), "/sys/bus/pci/devices/%s", slot_id);
  std::string pathStr = path;
  char generation[256];
  char lanes[256];
  if (read_sysfs_value((pathStr + "/current_link_speed").c_str(), generation, sizeof(generation))) {
    fprintf(stderr, "Failed to retrieve PCI-e information for %s\n", slot_id);
    return 1;
  }
  if (read_sysfs_value((pathStr + "/current_link_width").c_str(), lanes, sizeof(lanes))) {
    fprintf(stderr, "Failed to retrieve PCI-e information for %s\n", slot_id);
    return 1;
  }
  printf("PCI-e generation: %s", generation);
  printf("PCI-e lane count: %s", lanes);
  return 0;
}
