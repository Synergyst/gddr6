#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <pci/pci.h>
#define PG_SZ sysconf(_SC_PAGE_SIZE)
#define PCI_ID_BUFFER_SIZE 40
struct device {
  uint32_t bar0;
  uint8_t bus, dev, func;
  uint32_t offset;
  uint16_t vendor_id;
  uint16_t device_id;
  const char *vram;
  const char *arch;
  const char *name;
};
int fd;
void *map_base;
struct device devices[32];
struct device dev_table[] = {
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2684, .vram = "GDDR6X", .arch = "AD102", .name =  "RTX 4090" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2704, .vram = "GDDR6X", .arch = "AD103", .name =  "RTX 4080" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2782, .vram = "GDDR6X", .arch = "AD104", .name =  "RTX 4070 Ti" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2786, .vram = "GDDR6X", .arch = "AD104", .name =  "RTX 4070" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2204, .vram = "GDDR6X", .arch = "GA102", .name =  "RTX 3090" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2203, .vram = "GDDR6X", .arch = "GA102", .name =  "RTX 3090 Ti" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2208, .vram = "GDDR6X", .arch = "GA102", .name =  "RTX 3080 Ti" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2206, .vram = "GDDR6X", .arch = "GA102", .name =  "RTX 3080" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2216, .vram = "GDDR6X", .arch = "GA102", .name =  "RTX 3080 LHR" },
  { .offset = 0x0000EE50, .vendor_id = 0x10de, .device_id = 0x2484, .vram = "GDDR6",  .arch = "GA104", .name =  "RTX 3070" },
  { .offset = 0x0000EE50, .vendor_id = 0x10de, .device_id = 0x2488, .vram = "GDDR6",  .arch = "GA104", .name =  "RTX 3070 LHR" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2531, .vram = "GDDR6",  .arch = "GA106", .name =  "RTX A2000" },
  { .offset = 0x0000E2A8, .vendor_id = 0x10de, .device_id = 0x2571, .vram = "GDDR6",  .arch = "GA106", .name =  "RTX A2000" },
};
int pci_detect_dev(void);
int pci_detect_dev(void) {
  struct pci_access *pacc = NULL;
  struct pci_dev *pci_dev = NULL;
  int num_devs = 0;
  ssize_t dev_table_size = (sizeof(dev_table)/sizeof(struct device));
  pacc = pci_alloc();
  pci_init(pacc);
  pci_scan_bus(pacc);
  for (pci_dev = pacc->devices; pci_dev; pci_dev = pci_dev->next) {
    pci_fill_info(pci_dev, PCI_FILL_IDENT | PCI_FILL_BASES | PCI_FILL_CLASS);
    for (uint32_t i = 0; i < dev_table_size; i++) {
      if (pci_dev->device_id == dev_table[i].device_id && pci_dev->vendor_id == dev_table[i].vendor_id) {
        devices[num_devs] = dev_table[i];
        devices[num_devs].bar0 = (pci_dev->base_addr[0] & 0xFFFFFFFF);
        devices[num_devs].bus = pci_dev->bus;
        devices[num_devs].dev = pci_dev->dev;
        devices[num_devs].func = pci_dev->func;
        num_devs++;
      }
    }
  }
  pci_cleanup(pacc);
  return num_devs;
}
uint32_t fetch_gddr6_gddr6x_temp(const char *pci_id);
uint32_t fetch_gddr6_gddr6x_temp(const char *pci_id) {
  void *virt_addr;
  uint32_t temp, phys_addr, read_result, base_offset;
  int num_devs;
  num_devs = pci_detect_dev();
  if (num_devs == 0) {
    return -1;
  }
  if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) == -1) {
    return -1;
  }
  for (int i = 0; i < num_devs; i++) {
    struct device *device = &devices[i];
    phys_addr = (device->bar0 + device->offset);
    base_offset = phys_addr & ~(PG_SZ-1);
    map_base = mmap(0, PG_SZ, PROT_READ | PROT_WRITE, MAP_SHARED, fd, base_offset);
    if (map_base == (void*) -1) {
      if (fd != -1)
        close(fd);
      return -1;
    }
    virt_addr = (uint8_t*) map_base + (phys_addr - base_offset);
    read_result = *((uint32_t*) virt_addr);
    temp = ((read_result & 0x00000fff) / 0x20);
    char formattedValue[PCI_ID_BUFFER_SIZE];
    snprintf(formattedValue, sizeof(formattedValue), "%.2x:%.2x.%x", device->bus, device->dev, device->func);
    if (strcmp(formattedValue, pci_id) == 0) {
      if (map_base != (void *) -1) munmap(map_base, PG_SZ);
      if (fd != -1) close(fd);
      return temp;
    }
  }
  return -1;
}
