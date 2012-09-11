#ifndef CONSTRAINT_H
#define CONSTRAINT_H

#include <stdio.h>
#include <string.h>
#include "slice.h"
#include "error.h"

// ----- constants

enum eps_cmd {
  eps_invalid =   0u,  // invalid command

// must be firsts (weak commands)
  eps_dig     =   1u,  // relative input eps
  eps_rel     =   2u,  // relative eps
  eps_abs     =   4u,  // absolute eps
  eps_equ     =   8u,  // equal string
  eps_ign     =  16u,  // ignore value

// must be lasts (strong commands)
  eps_skip    =  32u,  // skip line
  eps_goto    =  64u,  // goto line
  eps_last
};

// ----- types

struct eps {
  enum eps_cmd cmd;
  double dig, rel, abs;
  char   tag[32];
};

struct constraint {
  struct slice row;
  struct slice col;
  struct eps   eps;
};

// ----- interface

#define T struct constraint

static inline struct eps
eps_init(enum eps_cmd cmd, double val)
{
  ensure(cmd > eps_invalid && cmd < eps_last, "invalid eps command");
  return (struct eps) { cmd, cmd&eps_dig ? val : 0, cmd&eps_rel ? val : 0, cmd&eps_abs ? val : 0, {0} };
}

static inline struct eps
eps_initNum(enum eps_cmd cmd, double dig, double rel, double abs)
{
  ensure(cmd > eps_invalid && cmd < eps_last, "invalid eps command");
  return (struct eps) { cmd, dig, rel, abs, {0} };
}

static inline struct eps
eps_initTag(enum eps_cmd cmd, const char *tag)
{
  ensure(cmd == eps_goto, "invalid eps goto command");
  struct eps eps = (struct eps) { .cmd = cmd };
  enum { sz = sizeof eps.tag };
  strncpy(eps.tag, tag, sz); eps.tag[sz-1] = 0;
  return eps;
}

static inline const char*
eps_cstr(enum eps_cmd cmd)
{
  extern const char * const eps_cmd_cstr[];
  return cmd > eps_invalid && cmd < eps_last && eps_cmd_cstr[cmd]
         ? eps_cmd_cstr[cmd]
         : eps_cmd_cstr[eps_invalid];
}

static inline T
constraint_init(const struct slice row, const struct slice col, const struct eps eps)
{
  return (T){ row, col, eps };
}

void constraint_print(const T* cst, FILE *out);
void constraint_scan (      T* cst, FILE *in, int *row);

#undef T

#endif

