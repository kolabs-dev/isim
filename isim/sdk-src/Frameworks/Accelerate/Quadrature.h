#pragma once
/* Quadrature (vecLib's Quadrature.h): numerical integration of a function over a finite interval, adapted by isim
   (frameworks/Accelerate/quadrature.c). */
#include <Accelerate/vecLibTypes.h>
#include <stddef.h>

typedef void (*quadrature_function_array)(void *arg, size_t n, const double *x, double *y);
typedef struct {
    quadrature_function_array fun;
    void *fun_arg;
} quadrature_integrate_function;

typedef enum {
    QUADRATURE_INTEGRATE_QNG = 0,
    QUADRATURE_INTEGRATE_QAG = 1,
    QUADRATURE_INTEGRATE_QAGS = 2,
} quadrature_integrator;

typedef enum {
    QUADRATURE_SUCCESS = 0,
    QUADRATURE_ERROR = -1,
    QUADRATURE_INVALID_ARG_ERROR = -2,
    QUADRATURE_INTERNAL_ERROR = -99,
    QUADRATURE_INTEGRATE_MAX_EVAL_ERROR = -101,
    QUADRATURE_INTEGRATE_BAD_BEHAVIOUR_ERROR = -102,
    QUADRATURE_ALLOC_ERROR = -100,
} quadrature_status;

typedef struct {
    quadrature_integrator integrator;
    double abs_tolerance;
    double rel_tolerance;
    size_t qag_points_per_interval;    /* QAG: 15, 21, 31, 41, 51 or 61 */
    size_t max_intervals;               /* QAG, QAGS */
} quadrature_integrate_options;

/* bytes of workspace per interval (isim allocates its own when the workspace given is too small) */
#define QUADRATURE_INTEGRATE_QAG_WORKSPACE_PER_INTERVAL 32
#define QUADRATURE_INTEGRATE_QAGS_WORKSPACE_PER_INTERVAL 48

VECLIB_EXTERN double quadrature_integrate(const quadrature_integrate_function *__f, double __a, double __b,
                                          const quadrature_integrate_options *__options, quadrature_status *__status,
                                          double *__abs_error, size_t __workspace_size, void *__workspace);
