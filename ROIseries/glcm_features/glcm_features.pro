;+
;  GLCM_FEATURES: Calculate various GLCM features
;  Copyright (C) 2016 Niklas Keck
;
;  This file is part of ROIseries.
;
;  ROIseries is free software: you can redistribute it and/or modify
;  it under the terms of the GNU Affero General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  ROIseries is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU Affero General Public License for more details.
;
;  You should have received a copy of the GNU Affero General Public License
;  along with ROIseries.  If not, see <http://www.gnu.org/licenses/>.
;-

;+
; Calculate various GLCM features
;
; :Params:
;    GLCM : in, required, type=numeric array
;        The GLCM array returned by the function GLCM_MATRIX
;    feature_names : in, required, type=strarr
;        array with 1 to all of the following:
;            ["CON","DIS","HOM","ASM","ENE","MAX","ENT","MEAN","VAR","STD","COR"]
;
; :Keywords:
;    IMG : in, required if feature_names contain one of ["MEAN", "VAR", "STD", "COR"]
;
; :Returns:
;
; :Examples:
;     For example::
;         IDL> img = [[0,0,1,1],[0,0,1,1],[0,2,2,2],[2,2,3,3]]
;         IDL> dir = 45
;         IDL> feature_names = ["CON","DIS","HOM","ASM","ENE","MAX","ENT","MEAN","VAR","STD","COR"]
;         IDL> glcm = GLCM_MATRIX(img,dir)
;         IDL> PRINT, glcm
;             0.222    0.055    0.000    0.000
;             0.055    0.111    0.111    0.000
;             0.000    0.111    0.222    0.055
;             0.000    0.000    0.055    0.000
;         IDL> features = GLCM_FEATURES(glcm, feature_names, IMG=img)
;         IDL> print,(HASH(feature_names, features))
;             CON:    0.4444
;             ENE:    0.3849
;             DIS:    0.4444
;             MAX:    0.2222
;             COR:    0.7352
;             MEAN:   1.2222
;             STD:    0.9162
;             HOM:    0.7778
;             ASM:    0.1481
;             VAR:    0.8395
;             ENT:    -2.043
;
; :Description:
;
;	:Uses:
;     GLCM_WSDM
; :Author:
;     Niklas Keck ("niklas_keck'use at instead'gmx.de").replace("'use at instead'","@")
;-
FUNCTION GLCM_FEATURES,GLCM,feature_names
    COMPILE_OPT idl2, HIDDEN
    
    n = (SIZE(glcm))[2]
    ; Check input
    IF n EQ 0 THEN MESSAGE,"Please provide GLCM"
    IF N_ELEMENTS(feature_names) EQ 0 THEN MESSAGE,"Please provide at least one feature"
    
    ; Check if GLCM was successfully calculated if not (e.g. for 1D Array) return D_NAN
    result=MAKE_ARRAY(N_ELEMENTS(feature_names),VALUE=!Values.F_NAN)
    IF TOTAL(FINITE(glcm)) LT 1 THEN RETURN, result
    
    ; GLCM features can be calculated on the subset of GLCM that excludes any '0' entries
    ; Consider e.g. TOTAL(glcm*...) this is a very common case for GLCM featrue calculation and is invariant to the number of glcm entries being 0
    glcm_non_0_indices = WHERE(glcm NE 0)
    glcm_non_0 = glcm[glcm_non_0_indices]
    
    ; Precalculations for "Contrast Group"
    superset=[feature_names,["CON","DIS","HOM"]]
    IF N_ELEMENTS(UNIQ(superset,SORT(superset))) LT N_ELEMENTS(superset) THEN BEGIN ; check if the sets feature_names and ["CON","DIS","HOM"] have common elements 
      weights = (GLCM_WSDM(n,2))[glcm_non_0_indices]
    ENDIF
    
    ; Precalculations for "Descriptive Stats Group"
    IF CONTAINS_ANY_RS(feature_names,["MEAN","VAR","STD","COR"]) THEN BEGIN
      ind=REBIN(INDGEN(n),n,n)
      ind_rot = (ROTATE(ind, 1))[glcm_non_0_indices]
      ind = ind[glcm_non_0_indices]
      
      glcm_mean = TOTAL(glcm_non_0*ind)
      IF CONTAINS_ANY_RS(feature_names,["VAR","STD","COR"]) THEN BEGIN
        glcm_var = TOTAL(glcm_non_0*((ind-glcm_mean)^2))
      ENDIF
    ENDIF
    
    IF CONTAINS_ANY_RS(feature_names,["ASM","ENE"]) THEN asm = TOTAL(glcm_non_0^2)
    
    
    c=0
    FOREACH f,feature_names DO BEGIN
      CASE f OF
        "CON": result[c] = TOTAL(glcm_non_0 * weights) ; Contrast
        "DIS": result[c] = TOTAL(glcm_non_0 * SQRT(weights)) ; Dissimilarity
        "HOM": result[c] = TOTAL(glcm_non_0 / (1 + weights)) ; Homogeneity == Inverse Difference Moment
        "ASM": result[c] =  asm ; Angular Second Moment
        "ENE": result[c] = SQRT(asm) ; Energy == Uniformity == SQRT(ASM)
        "MAX": result[c] = MAX(glcm_non_0,/NAN) ; Maximum probability. Side Note: Not commonly implemented since actual GLCM is not computed in most software packages.
        "ENT":result[c] =  -1 * TOTAL(glcm_non_0 * ALOG(glcm_non_0))
        "MEAN": result[c] = glcm_mean
        "VAR": result[c] = glcm_var
        "STD": result[c] = SQRT(glcm_var)
        ; simplified denominator (SQRT(glcm_var^2))=glcm_var ; this is true since: glcm_var can only be positive [glcm_var=TOTAL(glcm[0]*((ind-glcm_mean)^2))]
        "COR": result[c] = TOTAL(glcm_non_0*(ind_rot-glcm_mean)*(ind-glcm_mean)/(glcm_var))
      ENDCASE
      c++
    ENDFOREACH
    
    RETURN,result

END
