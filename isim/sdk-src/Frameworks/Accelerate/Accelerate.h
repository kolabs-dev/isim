#pragma once
/* isim Accelerate.framework: vecLib's BLAS (cblas.h), LAPACK (clapack.h), vDSP (vDSP.h) and vForce (vForce.h), and
   vImage (vImage.h), implemented by isim in C (frameworks/Accelerate); the Swift overlay adds the vDSP, vForce and
   vImage APIs. Quadrature (Quadrature.h) too. */
#include <Accelerate/vecLibTypes.h>
#include <Accelerate/cblas.h>
#include <Accelerate/clapack.h>
#include <Accelerate/vDSP.h>
#include <Accelerate/vForce.h>
#include <Accelerate/vImage.h>
#include <Accelerate/Quadrature.h>
#include <Accelerate/Sparse/Solve.h>
#include <Accelerate/BNNS/bnns.h>
