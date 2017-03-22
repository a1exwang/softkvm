#include <fcntl.h>
#include <unistd.h>
#include <linux/input.h>
#include <linux/uinput.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#define INPUT_BUFFER_SIZE 0x400
const char *MY_UIDEV_NAME = "awvinput0";

int setup_keyboard_dev(int fd) {
  if (ioctl(fd, UI_SET_EVBIT, EV_KEY) < 0) {
    fprintf(stderr, "ioctl: UI_SET_EVBIT failed\n");
    perror(NULL);
    exit(1);
  }
  if (ioctl(fd, UI_SET_EVBIT, EV_SYN) < 0) {
    perror(NULL);
    exit(1);
  }
  if (ioctl(fd, UI_SET_EVBIT, EV_MSC) < 0) {
    perror(NULL);
    exit(1);
  }
  for (int i = 0; i < KEY_CNT; ++i) {
    if (ioctl(fd, UI_SET_KEYBIT, i) < 0) {
      perror(NULL);
      exit(1);
    }
  }

  if (ioctl(fd, UI_SET_EVBIT, EV_REL) < 0) {
    perror(NULL);
    exit(1);
  }
  if (ioctl(fd, UI_SET_RELBIT, REL_X) < 0) {
    perror(NULL);
    exit(1);
  }
  if (ioctl(fd, UI_SET_RELBIT, REL_Y) < 0) {
    perror(NULL);
    exit(1);
  }
  if (ioctl(fd, UI_SET_RELBIT, REL_WHEEL) < 0) {
    perror(NULL);
    exit(1);
  }
  return 0;
}

int setup_uidev(const char *name) {
  int fd = open("/dev/uinput", O_WRONLY);
  if (fd <= 0) {
    fprintf(stderr, "Failed to open /dev/uinput\n");
    perror(NULL);
    exit(1);
  }
  setup_keyboard_dev(fd);

  struct uinput_user_dev uidev;

  memset(&uidev, 0, sizeof(uidev));

  snprintf(uidev.name, UINPUT_MAX_NAME_SIZE, "%s", name);
  uidev.id.bustype = 0;
  uidev.id.vendor  = 0;
  uidev.id.product = 0;
  uidev.id.version = 0;

  if (sizeof(uidev) != write(fd, &uidev, sizeof(uidev))) {
    fprintf(stderr, "write uinput failed");
    exit(1);
  }

  if (ioctl(fd, UI_DEV_CREATE) < 0) {
    fprintf(stderr, "create UI_DEV failed");
    exit(1);
  }

  return fd;
}


int main(int argc, const char **argv) {
  const char *my_dev_name = MY_UIDEV_NAME;
  if (argc >= 2) {
    my_dev_name = argv[1];
  }
  int ret;

  int fd = setup_uidev(my_dev_name);
  printf("Virtual uinput device created..\n");
  char buf[INPUT_BUFFER_SIZE];
  while (1) {
    struct input_event ev;

    memset(&ev, 0, sizeof(ev));
    int n = read(0, buf, sizeof(buf));

    int written = 0;
    while (written < n) {
      written += write(fd, buf + written, n - written);
    }

    if (ret < 0) {
      fprintf(stderr, "write file failed %d, need %d\n", ret, n);
      break;
    }
  }

  /* Clean up */
  ioctl(fd, UI_DEV_DESTROY);
  close(fd);

  printf("Success");
  return 0;
}
