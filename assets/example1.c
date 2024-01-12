#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

void handler(int signum) {
  char msg[] = "got SIGINT\n";
  write(STDOUT_FILENO, msg, sizeof(msg));
}

int main() {
  struct sigaction act;
  memset(&act, 0, sizeof(act));
  act.sa_handler = handler;
  sigaction(SIGINT, &act, NULL);
  for (;;) {
    pause();
    printf("handled signal\n");
  }
}
