-- =====================================================================
-- 03_template_entrega_taller1_v2.sql
-- Taller aplicado 1 - SQL avanzado + Transacciones (ACID) aplicado
-- Plantilla de entrega para estudiantes
--
-- IMPORTANTE:
-- 1. Trabajar únicamente sobre las tablas T1_% y AUDIT_SALARY_ADJUSTMENTS_T1
-- 2. NO modificar la estructura del entorno entregado por el docente
-- 3. NO eliminar secciones de esta plantilla
-- 4. Reemplazar únicamente los bloques indicados como "ESCRIBA AQUÍ"
-- 5. Usar la variante asignada por el docente (1, 2, 3 o 4)
-- 6. Usar un tag único de ejecución final, por ejemplo: P03_FINAL
-- =====================================================================

SET SERVEROUTPUT ON
SET FEEDBACK ON

-- ============================================================
-- 0. ENCABEZADO OBLIGATORIO
-- Complete toda esta información antes de ejecutar el script.
-- ============================================================
-- Integrante 1: David Esteban Caicedo
-- Integrante 2: Nicolas Zambrano
-- Curso: Bases de Datos 2
-- Fecha: 08/04/2026
-- Variante asignada por el docente (1, 2, 3 o 4): 3
-- Tag de ejecución final (ejemplo: P03_FINAL): P01_FINAL

DEFINE p_variant_id = 3;
DEFINE p_execution_tag = 'P01_FINAL';


PROMPT ===== 0. VERIFICACIÓN DE LA VARIANTE ASIGNADA =====
SELECT
    variant_id,
    variant_name,
    excluded_department_id,
    min_years_service,
    recent_job_history_months,
    gap_high_threshold_pct,
    gap_mid_threshold_pct,
    raise_high_pct,
    raise_mid_pct,
    raise_low_pct,
    max_salary_vs_avg_pct,
    notes
FROM t1_variants
WHERE variant_id = &p_variant_id;

-- ============================================================
-- GUÍA RÁPIDA DE OBJETOS DISPONIBLES
-- Use estos nombres reales de tablas y columnas.
-- ============================================================
-- Tabla principal de empleados: T1_EMPLOYEES
-- Columnas más importantes:
--   employee_id, first_name, last_name, email, phone_number,
--   hire_date, job_id, salary, commission_pct, manager_id, department_id
--
-- Tabla de departamentos: T1_DEPARTMENTS
-- Columnas más importantes:
--   department_id, department_name, manager_id, location_id
--
-- Tabla de historial laboral: T1_JOB_HISTORY
-- Columnas más importantes:
--   employee_id, start_date, end_date, job_id, department_id
--
-- Tabla de auditoría: AUDIT_SALARY_ADJUSTMENTS_T1
-- Columnas:
--   audit_id, execution_tag, variant_id, employee_id, department_id,
--   salary_before, salary_after, pct_gap_to_avg_before, rule_applied,
--   executed_by, executed_at, notes
--
-- Tabla de variantes: T1_VARIANTS
-- Columnas:
--   variant_id, variant_name, excluded_department_id, min_years_service,
--   recent_job_history_months, gap_high_threshold_pct,
--   gap_mid_threshold_pct, raise_high_pct, raise_mid_pct,
--   raise_low_pct, max_salary_vs_avg_pct, notes

-- ============================================================
-- GUÍA RÁPIDA DE TÉRMINOS QUE DEBE USAR EN SU SOLUCIÓN
-- ============================================================
-- CTE:
--   Una CTE es una consulta temporal escrita con WITH.
--   Sirve para dividir una consulta grande en partes más claras.
--
--   Ejemplo:
--   WITH dept_stats AS (
--       SELECT department_id, AVG(salary) avg_salary
--       FROM t1_employees
--       GROUP BY department_id
--   )
--   SELECT *
--   FROM dept_stats;
--
-- Función analítica:
--   Es una función como ROW_NUMBER, RANK o DENSE_RANK.
--   Sirve para calcular posiciones o comparaciones sin perder el detalle.
--
--   Ejemplo:
--   DENSE_RANK() OVER (PARTITION BY department_id ORDER BY salary DESC)
--
-- JOIN:
--   Es la unión entre tablas relacionadas, por ejemplo empleados y departamentos.
--
-- Subconsulta:
--   Es una consulta dentro de otra consulta.
--
-- SAVEPOINT:
--   Es un punto de restauración dentro de una transacción.
--   Permite devolver la operación a un punto intermedio con ROLLBACK TO.

-- ============================================================
-- 1. CONSULTA DIAGNÓSTICA
-- OBJETIVO:
-- Analizar la información antes de actualizar salarios.
--
-- SU CONSULTA DEBE MOSTRAR, COMO MÍNIMO, ESTAS COLUMNAS:
--   employee_id
--   first_name
--   last_name
--   job_id
--   manager_id
--   department_id
--   department_name
--   salary
--   hire_date
--   years_service
--   dept_avg_salary
--   dept_max_salary
--   dept_employee_count
--   pct_gap_to_avg
--   recent_job_history_flag
--   salary_rank_in_department
--
-- QUÉ SIGNIFICA CADA COLUMNA:
--   years_service: años de antigüedad del empleado
--   dept_avg_salary: promedio salarial del departamento
--   dept_max_salary: salario más alto del departamento
--   dept_employee_count: cantidad de empleados del departamento
--   pct_gap_to_avg: porcentaje que le falta al salario del empleado para llegar
--                   al promedio del departamento
--   recent_job_history_flag: SI o NO, según si tuvo historial reciente
--   salary_rank_in_department: posición salarial dentro del departamento
--
-- IMPORTANTE:
-- - Puede usar una o varias CTE
-- - Debe usar al menos una función analítica
-- - Debe unir como mínimo T1_EMPLOYEES con T1_DEPARTMENTS
-- - Debe revisar T1_JOB_HISTORY para detectar historial reciente
-- ============================================================

PROMPT ===== 1. CONSULTA DIAGNÓSTICA =====

-- ESCRIBA AQUÍ SU CONSULTA DIAGNÓSTICA PRINCIPAL
-- Debe devolver las columnas mínimas exigidas arriba.


WITH
    metricas_depto AS (
        SELECT
            emp.department_id,
            AVG(emp.salary)  AS dept_avg_salary,
            MAX(emp.salary)  AS dept_max_salary,
            COUNT(*)         AS dept_employee_count
        FROM t1_employees emp
        WHERE emp.department_id IS NOT NULL
        GROUP BY emp.department_id
    ),
    con_historial_reciente AS (
        SELECT DISTINCT
            jh.employee_id,
            'SI' AS recent_flag
        FROM t1_job_history jh
        CROSS JOIN t1_variants var
        WHERE var.variant_id = &p_variant_id
          AND jh.end_date >= ADD_MONTHS(TRUNC(SYSDATE), -var.recent_job_history_months)
    )

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.job_id,
    e.manager_id,
    e.department_id,
    dep.department_name,
    e.salary,
    e.hire_date,
    ROUND(MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12, 2)                        AS years_service,
    ROUND(md.dept_avg_salary, 2)                                                AS dept_avg_salary,
    ROUND(md.dept_max_salary, 2)                                                AS dept_max_salary,
    md.dept_employee_count,
    ROUND(((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100, 2)     AS pct_gap_to_avg,
    NVL(chr.recent_flag, 'NO')                                                  AS recent_job_history_flag,
    DENSE_RANK() OVER (
        PARTITION BY e.department_id
        ORDER BY e.salary DESC
    )                                                                           AS salary_rank_in_department
FROM      t1_employees   e
LEFT JOIN t1_departments dep ON dep.department_id = e.department_id
LEFT JOIN metricas_depto  md  ON md.department_id  = e.department_id
LEFT JOIN con_historial_reciente chr ON chr.employee_id = e.employee_id
ORDER BY e.department_id NULLS LAST, e.salary DESC;


 
-- COMENTARIO OBLIGATORIO:
-- La consulta diagnóstica muestra, para cada empleado, su situación salarial
-- respecto al promedio de su departamento (pct_gap_to_avg), cuántos años lleva
-- en la empresa (years_service), si tuvo movimientos laborales recientes
-- (recent_job_history_flag) y cuál es su posición dentro del ranking salarial
-- del departamento. Esta visión previa permite identificar quiénes cumplen
-- los criterios de elegibilidad antes de ejecutar cualquier cambio, evitando
-- ajustes sobre personal excluido o que no cumple los umbrales de la Variante 3.
 
 

-- ============================================================
-- 2. DECISIÓN DE POBLACIÓN ELEGIBLE
-- OBJETIVO:
-- Determinar qué empleados sí califican, cuáles no califican y por qué.
--
-- SU CONSULTA DEBE MOSTRAR, COMO MÍNIMO, ESTAS COLUMNAS:
--   employee_id
--   first_name
--   last_name
--   department_id
--   department_name
--   salary
--   years_service
--   dept_avg_salary
--   dept_max_salary
--   dept_employee_count
--   pct_gap_to_avg
--   recent_job_history_flag
--   manager_or_exec_flag
--   eligibility_flag
--   exclusion_reason
--   adjustment_pct
--   rule_applied
--
-- QUÉ SIGNIFICA CADA COLUMNA:
--   manager_or_exec_flag: SI o NO, según si es gerente principal o alta dirección
--   eligibility_flag: ELEGIBLE o NO_ELEGIBLE
--   exclusion_reason: motivo de exclusión, por ejemplo:
--                     SIN_DEPARTAMENTO, HISTORIAL_RECIENTE,
--                     ANTIGUEDAD_INSUFICIENTE, MANAGER_O_DIRECTIVO,
--                     DEPTO_EXCLUIDO, DEPTO_MENOR_A_3, SALARIO_NO_APLICA
--   adjustment_pct: porcentaje de ajuste que le corresponde
--   rule_applied: regla aplicada, por ejemplo AJUSTE_ALTO, AJUSTE_MEDIO, AJUSTE_BAJO
--
-- IMPORTANTE:
-- - Debe tomar en cuenta la variante asignada por el docente
-- - Debe usar los valores de T1_VARIANTS según &p_variant_id
-- - Debe quedar visible por qué una persona sí o no entra al proceso
-- ============================================================

PROMPT ===== 2. DECISIÓN DE ELEGIBLES =====

-- ESCRIBA AQUÍ SU CONSULTA DE DECISIÓN DE ELEGIBLES
-- Debe devolver las columnas mínimas exigidas arriba.


WITH
    metricas_depto AS (
        SELECT
            emp.department_id,
            AVG(emp.salary) AS dept_avg_salary,
            MAX(emp.salary) AS dept_max_salary,
            COUNT(*)        AS dept_employee_count
        FROM t1_employees emp
        WHERE emp.department_id IS NOT NULL
        GROUP BY emp.department_id
    ),
    con_historial_reciente AS (
        SELECT DISTINCT jh.employee_id, 'SI' AS recent_flag
        FROM t1_job_history jh
        CROSS JOIN t1_variants var
        WHERE var.variant_id = &p_variant_id
          AND jh.end_date >= ADD_MONTHS(TRUNC(SYSDATE), -var.recent_job_history_months)
    ),
    lista_managers AS (
        SELECT DISTINCT manager_id
        FROM t1_employees
        WHERE manager_id IS NOT NULL
    ),
    config_variante AS (
        SELECT
            excluded_department_id,
            min_years_service,
            recent_job_history_months,
            gap_high_threshold_pct,
            gap_mid_threshold_pct,
            raise_high_pct,
            raise_mid_pct,
            raise_low_pct,
            max_salary_vs_avg_pct
        FROM t1_variants
        WHERE variant_id = &p_variant_id
    )

SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.department_id,
    dep.department_name,
    e.salary,
    ROUND(MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12, 2)                    AS years_service,
    ROUND(md.dept_avg_salary, 2)                                            AS dept_avg_salary,
    ROUND(md.dept_max_salary, 2)                                            AS dept_max_salary,
    md.dept_employee_count,
    ROUND(((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100, 2) AS pct_gap_to_avg,
    NVL(chr.recent_flag, 'NO')                                              AS recent_job_history_flag,

    CASE
        WHEN lm.manager_id IS NOT NULL THEN 'SI'
        WHEN e.job_id LIKE '%_VP'      THEN 'SI'
        WHEN e.job_id LIKE 'AD_%'      THEN 'SI'
        ELSE 'NO'
    END AS manager_or_exec_flag,

    CASE
        WHEN e.department_id IS NULL                                                     THEN 'NO_ELEGIBLE'
        WHEN e.department_id = cfg.excluded_department_id                                THEN 'NO_ELEGIBLE'
        WHEN md.dept_employee_count < 3                                                  THEN 'NO_ELEGIBLE'
        WHEN MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12 < cfg.min_years_service          THEN 'NO_ELEGIBLE'
        WHEN NVL(chr.recent_flag, 'NO') = 'SI'                                           THEN 'NO_ELEGIBLE'
        WHEN lm.manager_id IS NOT NULL OR e.job_id LIKE '%_VP' OR e.job_id LIKE 'AD_%'  THEN 'NO_ELEGIBLE'
        WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 <= 0          THEN 'NO_ELEGIBLE'
        ELSE 'ELEGIBLE'
    END AS eligibility_flag,

    CASE
        WHEN e.department_id IS NULL                                                     THEN 'SIN_DEPARTAMENTO'
        WHEN e.department_id = cfg.excluded_department_id                                THEN 'DEPTO_EXCLUIDO'
        WHEN md.dept_employee_count < 3                                                  THEN 'DEPTO_MENOR_A_3'
        WHEN MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12 < cfg.min_years_service          THEN 'ANTIGUEDAD_INSUFICIENTE'
        WHEN NVL(chr.recent_flag, 'NO') = 'SI'                                           THEN 'HISTORIAL_RECIENTE'
        WHEN lm.manager_id IS NOT NULL OR e.job_id LIKE '%_VP' OR e.job_id LIKE 'AD_%'  THEN 'MANAGER_O_DIRECTIVO'
        WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 <= 0          THEN 'SALARIO_NO_APLICA'
        ELSE NULL
    END AS exclusion_reason,

    CASE
        WHEN e.department_id IS NULL
          OR e.department_id = cfg.excluded_department_id
          OR md.dept_employee_count < 3
          OR MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12 < cfg.min_years_service
          OR NVL(chr.recent_flag, 'NO') = 'SI'
          OR lm.manager_id IS NOT NULL
          OR e.job_id LIKE '%_VP'
          OR e.job_id LIKE 'AD_%'
          OR ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 <= 0  THEN NULL
        WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_high_threshold_pct THEN cfg.raise_high_pct
        WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_mid_threshold_pct  THEN cfg.raise_mid_pct
        ELSE cfg.raise_low_pct
    END AS adjustment_pct,

    CASE
        WHEN e.department_id IS NULL
          OR e.department_id = cfg.excluded_department_id
          OR md.dept_employee_count < 3
          OR MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12 < cfg.min_years_service
          OR NVL(chr.recent_flag, 'NO') = 'SI'
          OR lm.manager_id IS NOT NULL
          OR e.job_id LIKE '%_VP'
          OR e.job_id LIKE 'AD_%'
          OR ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 <= 0  THEN NULL
        WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_high_threshold_pct THEN 'AJUSTE_ALTO'
        WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_mid_threshold_pct  THEN 'AJUSTE_MEDIO'
        ELSE 'AJUSTE_BAJO'
    END AS rule_applied

FROM      t1_employees         e
LEFT JOIN t1_departments        dep ON dep.department_id = e.department_id
LEFT JOIN metricas_depto        md  ON md.department_id  = e.department_id
LEFT JOIN con_historial_reciente chr ON chr.employee_id  = e.employee_id
LEFT JOIN lista_managers         lm  ON lm.manager_id    = e.employee_id
CROSS JOIN config_variante       cfg
ORDER BY eligibility_flag DESC, e.department_id, pct_gap_to_avg DESC;
 
-- COMENTARIO OBLIGATORIO:
-- La Variante 3 impone cuatro filtros principales: excluir el departamento 100,
-- exigir mínimo 4 años de antigüedad, excluir empleados con movimientos laborales
-- en los últimos 24 meses, y excluir managers/directivos. Adicionalmente, los
-- departamentos con menos de 3 empleados quedan fuera del proceso, y solo
-- reciben ajuste quienes están por debajo del promedio salarial de su área.
-- Los porcentajes de raise (7%, 4%, 2%) se asignan según la brecha (≥12%, ≥6%, <6%),
-- garantizando que ningún ajuste supere el 118% del promedio departamental.
 

-- ============================================================
-- 3. PREVALIDACIÓN ANTES DE LA TRANSACCIÓN
-- OBJETIVO:
-- Mostrar qué pasaría antes de ejecutar el cambio real.
--
-- DEBE MOSTRAR, COMO MÍNIMO:
-- A. Un resumen con estas columnas:
--    total_eligible_employees
--    total_salary_before
--    total_salary_after
--    total_increment
--
-- B. Un detalle de empleados elegibles con estas columnas:
--    employee_id
--    department_id
--    salary_before
--    salary_after
--    adjustment_pct
--    rule_applied
--
-- C. Un control de topes por departamento con estas columnas:
--    department_id
--    department_name
--    dept_avg_salary
--    dept_max_salary
--    max_allowed_salary_by_variant
--
-- QUÉ SIGNIFICA:
--   total_salary_before: suma de salarios antes del ajuste
--   total_salary_after: suma de salarios proyectados después del ajuste
--   total_increment: incremento total proyectado
--   max_allowed_salary_by_variant: salario máximo permitido según la variante
-- ============================================================

PROMPT ===== 3. PREVALIDACIÓN =====

-- ESCRIBA AQUÍ SU CONSULTA O SUS CONSULTAS DE PREVALIDACIÓN
-- Debe mostrar el resumen, el detalle y el control de topes.


-- A. Resumen de impacto proyectado
WITH
    metricas_depto AS (
        SELECT department_id,
               AVG(salary) AS dept_avg_salary,
               MAX(salary) AS dept_max_salary,
               COUNT(*)    AS dept_employee_count
        FROM t1_employees
        WHERE department_id IS NOT NULL
        GROUP BY department_id
    ),
    con_historial_reciente AS (
        SELECT DISTINCT jh.employee_id, 'SI' AS recent_flag
        FROM t1_job_history jh
        CROSS JOIN t1_variants var
        WHERE var.variant_id = &p_variant_id
          AND jh.end_date >= ADD_MONTHS(TRUNC(SYSDATE), -var.recent_job_history_months)
    ),
    lista_managers AS (
        SELECT DISTINCT manager_id FROM t1_employees WHERE manager_id IS NOT NULL
    ),
    config_variante AS (
        SELECT excluded_department_id, min_years_service,
               gap_high_threshold_pct, gap_mid_threshold_pct,
               raise_high_pct, raise_mid_pct, raise_low_pct,
               max_salary_vs_avg_pct
        FROM t1_variants WHERE variant_id = &p_variant_id
    ),
    candidatos AS (
        SELECT e.employee_id,
               e.department_id,
               e.salary                                                              AS salary_before,
               md.dept_avg_salary,
               ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100         AS brecha_pct,
               CASE
                   WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_high_threshold_pct THEN cfg.raise_high_pct
                   WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_mid_threshold_pct  THEN cfg.raise_mid_pct
                   ELSE cfg.raise_low_pct
               END AS adjustment_pct,
               CASE
                   WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_high_threshold_pct THEN 'AJUSTE_ALTO'
                   WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_mid_threshold_pct  THEN 'AJUSTE_MEDIO'
                   ELSE 'AJUSTE_BAJO'
               END AS rule_applied,
               cfg.max_salary_vs_avg_pct
        FROM t1_employees e
        JOIN  metricas_depto         md  ON md.department_id = e.department_id
        JOIN  config_variante        cfg ON 1 = 1
        LEFT JOIN con_historial_reciente chr ON chr.employee_id = e.employee_id
        LEFT JOIN lista_managers         lm  ON lm.manager_id  = e.employee_id
        WHERE e.department_id IS NOT NULL
          AND e.department_id <> cfg.excluded_department_id
          AND md.dept_employee_count >= 3
          AND MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12 >= cfg.min_years_service
          AND NVL(chr.recent_flag, 'NO') = 'NO'
          AND lm.manager_id IS NULL
          AND e.job_id NOT LIKE '%_VP'
          AND e.job_id NOT LIKE 'AD_%'
          AND ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 > 0
    ),
    candidatos_proyectados AS (
        SELECT c.*,
               LEAST(
                   ROUND(c.salary_before * (1 + c.adjustment_pct / 100), 2),
                   ROUND(c.dept_avg_salary * c.max_salary_vs_avg_pct / 100, 2)
               ) AS salary_after
        FROM candidatos c
    )
SELECT
    COUNT(*)                                     AS total_eligible_employees,
    ROUND(SUM(salary_before), 2)                AS total_salary_before,
    ROUND(SUM(salary_after), 2)                 AS total_salary_after,
    ROUND(SUM(salary_after - salary_before), 2) AS total_increment
FROM candidatos_proyectados;



-- B. Detalle por empleado elegible
WITH
    metricas_depto AS (
        SELECT department_id,
               AVG(salary) AS dept_avg_salary,
               MAX(salary) AS dept_max_salary,
               COUNT(*)    AS dept_employee_count
        FROM t1_employees
        WHERE department_id IS NOT NULL
        GROUP BY department_id
    ),
    con_historial_reciente AS (
        SELECT DISTINCT jh.employee_id, 'SI' AS recent_flag
        FROM t1_job_history jh
        CROSS JOIN t1_variants var
        WHERE var.variant_id = &p_variant_id
          AND jh.end_date >= ADD_MONTHS(TRUNC(SYSDATE), -var.recent_job_history_months)
    ),
    lista_managers AS (
        SELECT DISTINCT manager_id FROM t1_employees WHERE manager_id IS NOT NULL
    ),
    config_variante AS (
        SELECT excluded_department_id, min_years_service,
               gap_high_threshold_pct, gap_mid_threshold_pct,
               raise_high_pct, raise_mid_pct, raise_low_pct,
               max_salary_vs_avg_pct
        FROM t1_variants WHERE variant_id = &p_variant_id
    ),
    candidatos AS (
        SELECT e.employee_id,
               e.department_id,
               e.salary                                                              AS salary_before,
               md.dept_avg_salary,
               ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100         AS brecha_pct,
               CASE
                   WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_high_threshold_pct THEN cfg.raise_high_pct
                   WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_mid_threshold_pct  THEN cfg.raise_mid_pct
                   ELSE cfg.raise_low_pct
               END AS adjustment_pct,
               CASE
                   WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_high_threshold_pct THEN 'AJUSTE_ALTO'
                   WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 >= cfg.gap_mid_threshold_pct  THEN 'AJUSTE_MEDIO'
                   ELSE 'AJUSTE_BAJO'
               END AS rule_applied,
               cfg.max_salary_vs_avg_pct
        FROM t1_employees e
        JOIN  metricas_depto         md  ON md.department_id = e.department_id
        JOIN  config_variante        cfg ON 1 = 1
        LEFT JOIN con_historial_reciente chr ON chr.employee_id = e.employee_id
        LEFT JOIN lista_managers         lm  ON lm.manager_id  = e.employee_id
        WHERE e.department_id IS NOT NULL
          AND e.department_id <> cfg.excluded_department_id
          AND md.dept_employee_count >= 3
          AND MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12 >= cfg.min_years_service
          AND NVL(chr.recent_flag, 'NO') = 'NO'
          AND lm.manager_id IS NULL
          AND e.job_id NOT LIKE '%_VP'
          AND e.job_id NOT LIKE 'AD_%'
          AND ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 > 0
    ),
    candidatos_proyectados AS (
        SELECT c.*,
               LEAST(
                   ROUND(c.salary_before * (1 + c.adjustment_pct / 100), 2),
                   ROUND(c.dept_avg_salary * c.max_salary_vs_avg_pct / 100, 2)
               ) AS salary_after
        FROM candidatos c
    )
SELECT
    employee_id,
    department_id,
    salary_before,
    salary_after,
    adjustment_pct,
    rule_applied
FROM candidatos_proyectados
ORDER BY department_id, salary_before;


-- C. Control de topes por departamento
WITH
    metricas_depto AS (
        SELECT department_id,
               AVG(salary) AS dept_avg_salary,
               MAX(salary) AS dept_max_salary,
               COUNT(*)    AS dept_employee_count
        FROM t1_employees
        WHERE department_id IS NOT NULL
        GROUP BY department_id
    ),
    con_historial_reciente AS (
        SELECT DISTINCT jh.employee_id, 'SI' AS recent_flag
        FROM t1_job_history jh
        CROSS JOIN t1_variants var
        WHERE var.variant_id = &p_variant_id
          AND jh.end_date >= ADD_MONTHS(TRUNC(SYSDATE), -var.recent_job_history_months)
    ),
    lista_managers AS (
        SELECT DISTINCT manager_id FROM t1_employees WHERE manager_id IS NOT NULL
    ),
    config_variante AS (
        SELECT excluded_department_id, min_years_service,
               gap_high_threshold_pct, gap_mid_threshold_pct,
               raise_high_pct, raise_mid_pct, raise_low_pct,
               max_salary_vs_avg_pct
        FROM t1_variants WHERE variant_id = &p_variant_id
    ),
    candidatos AS (
        SELECT e.employee_id,
               e.department_id,
               e.salary                 AS salary_before,
               md.dept_avg_salary,
               md.dept_max_salary,
               cfg.max_salary_vs_avg_pct
        FROM t1_employees e
        JOIN  metricas_depto         md  ON md.department_id = e.department_id
        JOIN  config_variante        cfg ON 1 = 1
        LEFT JOIN con_historial_reciente chr ON chr.employee_id = e.employee_id
        LEFT JOIN lista_managers         lm  ON lm.manager_id  = e.employee_id
        WHERE e.department_id IS NOT NULL
          AND e.department_id <> cfg.excluded_department_id
          AND md.dept_employee_count >= 3
          AND MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12 >= cfg.min_years_service
          AND NVL(chr.recent_flag, 'NO') = 'NO'
          AND lm.manager_id IS NULL
          AND e.job_id NOT LIKE '%_VP'
          AND e.job_id NOT LIKE 'AD_%'
          AND ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 > 0
    )
SELECT DISTINCT
    c.department_id,
    dep.department_name,
    ROUND(c.dept_avg_salary, 2)                                     AS dept_avg_salary,
    ROUND(c.dept_max_salary, 2)                                     AS dept_max_salary,
    ROUND(c.dept_avg_salary * c.max_salary_vs_avg_pct / 100, 2)    AS max_allowed_salary_by_variant
FROM candidatos c
JOIN t1_departments dep ON dep.department_id = c.department_id
ORDER BY c.department_id;


-- ============================================================
-- 4. EJECUCIÓN TRANSACCIONAL
-- OBJETIVO:
-- Ejecutar la actualización real y registrar la auditoría.
--
-- DEBE INCLUIR OBLIGATORIAMENTE:
-- 1. SAVEPOINT
-- 2. UPDATE o MERGE para actualizar salarios
-- 3. INSERT a AUDIT_SALARY_ADJUSTMENTS_T1
-- 4. Validación intermedia
-- 5. COMMIT o ROLLBACK TO SAVEPOINT
--
-- IMPORTANTE:
-- - La auditoría debe usar el valor &p_execution_tag
-- - La auditoría debe usar el valor &p_variant_id
-- - Debe usar la secuencia AUDIT_SALARY_ADJ_T1_SEQ.NEXTVAL
-- ============================================================

PROMPT ===== 4. EJECUCIÓN TRANSACCIONAL =====

SAVEPOINT sv_before_adjustment;



-- 4.1 ACTUALIZACIÓN DE SALARIOS

UPDATE t1_employees e
SET e.salary = (
    SELECT
        LEAST(
            ROUND(e.salary * (1 +
                CASE
                    WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100
                         >= cfg.gap_high_threshold_pct THEN cfg.raise_high_pct
                    WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100
                         >= cfg.gap_mid_threshold_pct  THEN cfg.raise_mid_pct
                    ELSE cfg.raise_low_pct
                END / 100), 2),
            ROUND(md.dept_avg_salary * cfg.max_salary_vs_avg_pct / 100, 2)
        )
    FROM (
        SELECT department_id,
               AVG(salary) AS dept_avg_salary,
               COUNT(*)    AS dept_employee_count
        FROM t1_employees
        WHERE department_id IS NOT NULL
        GROUP BY department_id
    ) md
    JOIN t1_variants cfg ON cfg.variant_id = &p_variant_id
    WHERE md.department_id = e.department_id
)
WHERE EXISTS (
    SELECT 1
    FROM audit_salary_adjustments_t1 aud
    WHERE aud.employee_id   = e.employee_id
      AND aud.execution_tag = '&p_execution_tag'
);


-- 4.2 INSERCIÓN EN AUDITORÍA (primero se registra el plan)

INSERT INTO audit_salary_adjustments_t1 (
    audit_id,
    execution_tag,
    variant_id,
    employee_id,
    department_id,
    salary_before,
    salary_after,
    pct_gap_to_avg_before,
    rule_applied,
    executed_by,
    executed_at,
    notes
)
SELECT
    audit_salary_adj_t1_seq.NEXTVAL,
    '&p_execution_tag',
    &p_variant_id,
    calc.employee_id,
    calc.department_id,
    calc.salary_before,
    calc.salary_after,
    ROUND(calc.brecha_pct, 4),
    calc.rule_applied,
    USER,
    SYSDATE,
    'Variante 3 - Ajuste controlado. Tag: &p_execution_tag'
FROM (
    SELECT
        e.employee_id,
        e.department_id,
        e.salary                                                              AS salary_before,
        ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100         AS brecha_pct,
        LEAST(
            ROUND(e.salary * (1 +
                CASE
                    WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100
                         >= cfg.gap_high_threshold_pct THEN cfg.raise_high_pct
                    WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100
                         >= cfg.gap_mid_threshold_pct  THEN cfg.raise_mid_pct
                    ELSE cfg.raise_low_pct
                END / 100), 2),
            ROUND(md.dept_avg_salary * cfg.max_salary_vs_avg_pct / 100, 2)
        ) AS salary_after,
        CASE
            WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100
                 >= cfg.gap_high_threshold_pct THEN 'AJUSTE_ALTO'
            WHEN ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100
                 >= cfg.gap_mid_threshold_pct  THEN 'AJUSTE_MEDIO'
            ELSE 'AJUSTE_BAJO'
        END AS rule_applied
    FROM t1_employees e
    JOIN (
        SELECT department_id,
               AVG(salary) AS dept_avg_salary,
               COUNT(*)    AS dept_employee_count
        FROM t1_employees
        WHERE department_id IS NOT NULL
        GROUP BY department_id
    ) md ON e.department_id = md.department_id
    JOIN t1_variants cfg ON cfg.variant_id = &p_variant_id
    WHERE e.department_id IS NOT NULL
      AND e.department_id <> cfg.excluded_department_id
      AND md.dept_employee_count >= 3
      AND MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12 >= cfg.min_years_service
      AND NOT EXISTS (
          SELECT 1 FROM t1_job_history jh
          WHERE jh.employee_id = e.employee_id
            AND jh.end_date >= ADD_MONTHS(TRUNC(SYSDATE), -cfg.recent_job_history_months)
      )
      AND e.employee_id NOT IN (
          SELECT DISTINCT manager_id FROM t1_employees WHERE manager_id IS NOT NULL
      )
      AND e.job_id NOT LIKE '%_VP'
      AND e.job_id NOT LIKE 'AD_%'
      AND ((md.dept_avg_salary - e.salary) / md.dept_avg_salary) * 100 > 0
) calc;

-- 4.3 VALIDACIÓN INTERMEDIA

SELECT
    aud.employee_id,
    aud.department_id,
    emp.salary                                                          AS current_salary,
    aud.salary_before                                                   AS original_salary,
    ROUND(stats.dept_avg_salary * cfg.max_salary_vs_avg_pct / 100, 2) AS allowed_max_salary,
    CASE
        WHEN emp.salary <= ROUND(stats.dept_avg_salary * cfg.max_salary_vs_avg_pct / 100, 2)
             THEN 'CUMPLE'
        ELSE 'EXCEDE_TOPE'
    END AS validation_status
FROM audit_salary_adjustments_t1 aud
JOIN t1_employees emp ON emp.employee_id = aud.employee_id
JOIN (
    SELECT department_id, AVG(salary) AS dept_avg_salary
    FROM t1_employees
    WHERE department_id IS NOT NULL
    GROUP BY department_id
) stats ON stats.department_id = aud.department_id
JOIN t1_variants cfg ON cfg.variant_id = &p_variant_id
WHERE aud.execution_tag = '&p_execution_tag'
ORDER BY aud.department_id;



COMMIT;
-- ============================================================
-- 5. VALIDACIÓN POSTERIOR
-- OBJETIVO:
-- Demostrar el resultado final de la transacción.
--
-- DEBE MOSTRAR, COMO MÍNIMO, ESTAS 4 SALIDAS:
--
-- SALIDA 1. Empleados impactados
-- Columnas mínimas:
--   employee_id, first_name, last_name, department_id,
--   salary_before, salary_after, execution_tag
--
-- SALIDA 2. Resumen económico final
-- Columnas mínimas:
--   total_rows_audited, total_salary_before, total_salary_after, total_increment
--
-- SALIDA 3. Validación de topes
-- Columnas mínimas:
--   employee_id, department_id, salary_after, allowed_max_salary, top_limit_status
--
-- SALIDA 4. Auditoría generada
-- Columnas mínimas:
--   audit_id, execution_tag, variant_id, employee_id, department_id,
--   salary_before, salary_after, rule_applied, executed_by, executed_at
--
-- IMPORTANTE:
-- Todas las validaciones posteriores deben filtrar por &p_execution_tag
-- ============================================================

PROMPT ===== 5. VALIDACIÓN POSTERIOR =====

-- SALIDA 1: Empleados impactados
SELECT
    aud.employee_id,
    emp.first_name,
    emp.last_name,
    aud.department_id,
    aud.salary_before,
    aud.salary_after,
    aud.execution_tag
FROM audit_salary_adjustments_t1 aud
JOIN t1_employees emp ON emp.employee_id = aud.employee_id
WHERE aud.execution_tag = '&p_execution_tag'
ORDER BY aud.department_id;

-- SALIDA 2: Resumen económico final
SELECT
    COUNT(*)                                     AS total_rows_audited,
    ROUND(SUM(salary_before), 2)                AS total_salary_before,
    ROUND(SUM(salary_after), 2)                 AS total_salary_after,
    ROUND(SUM(salary_after - salary_before), 2) AS total_increment
FROM audit_salary_adjustments_t1
WHERE execution_tag = '&p_execution_tag';

-- SALIDA 3: Validación de topes
SELECT
    aud.employee_id,
    aud.department_id,
    aud.salary_after,
    ROUND(stats.dept_avg_salary * cfg.max_salary_vs_avg_pct / 100, 2) AS allowed_max_salary,
    CASE
        WHEN aud.salary_after <= ROUND(stats.dept_avg_salary * cfg.max_salary_vs_avg_pct / 100, 2)
             THEN 'CUMPLE'
        ELSE 'EXCEDE_TOPE'
    END AS top_limit_status
FROM audit_salary_adjustments_t1 aud
JOIN (
    SELECT department_id, AVG(salary) AS dept_avg_salary
    FROM t1_employees
    WHERE department_id IS NOT NULL
    GROUP BY department_id
) stats ON stats.department_id = aud.department_id
JOIN t1_variants cfg ON cfg.variant_id = &p_variant_id
WHERE aud.execution_tag = '&p_execution_tag'
ORDER BY aud.department_id;

-- SALIDA 4: Registro completo de auditoría
SELECT
    audit_id,
    execution_tag,
    variant_id,
    employee_id,
    department_id,
    salary_before,
    salary_after,
    rule_applied,
    executed_by,
    executed_at
FROM audit_salary_adjustments_t1
WHERE execution_tag = '&p_execution_tag'
ORDER BY audit_id;



-- ============================================================
-- 6. JUSTIFICACIÓN TÉCNICA
-- Responder dentro del script, en comentarios.
-- Cada respuesta debe tener entre 3 y 6 líneas.
-- ============================================================

-- ATOMICIDAD:
-- Explique cómo su solución demuestra atomicidad.
--
-- RESPUESTA: 
-- La solución aplica atomicidad mediante una transacción explícita que
-- agrupa el INSERT de auditoría y el UPDATE de salarios como una sola
-- unidad lógica de trabajo. El SAVEPOINT sv_before_adjustment permite
-- revertir ambas operaciones si la validación intermedia detecta
-- incumplimientos, garantizando que la base de datos nunca quede en
-- un estado parcialmente modificado y cumpliendo el principio de
-- "todo o nada" en cada ejecución del proceso.



-- CONSISTENCIA:
-- Explique cómo su solución asegura que los datos quedan válidos
-- después de la operación.
--
-- RESPUESTA: 
--  La consistencia se mantiene aplicando las reglas de negocio de la
--  variante antes, durante y después de la transacción: antigüedad
--  mínima, exclusión del departamento indicado, ausencia de historial
--  reciente y límite máximo salarial. La prevalidación anticipa el
--  impacto de los cambios y la validación posterior verifica que los
--  datos finales cumplen todas las restricciones, asegurando que la
--  base de datos transite de un estado válido a otro igualmente válido.



-- AISLAMIENTO:
-- Explique cómo se comportaría su transacción frente a otras sesiones.
--
-- RESPUESTA:
-- Los cambios realizados dentro de la transacción no son visibles para
-- otras sesiones hasta que se ejecuta el COMMIT. Oracle gestiona este
-- comportamiento mediante MVCC (control de concurrencia multiversión),
-- lo que impide lecturas sucias, lecturas no repetibles y phantom reads.
-- Otras sesiones concurrentes ven el estado anterior de los datos hasta
-- que esta transacción confirma, garantizando integridad ante accesos
-- paralelos al sistema.



-- DURABILIDAD:
-- Explique qué garantiza la persistencia del cambio una vez confirmado.
--
-- RESPUESTA:
-- Una vez ejecutado el COMMIT, los cambios quedan persistidos de forma
-- permanente mediante los redo logs de Oracle, que garantizan la
-- recuperación de los datos incluso ante fallos del sistema. La tabla
-- AUDIT_SALARY_ADJUSTMENTS_T1 actúa como evidencia permanente de cada
-- ajuste, registrando el valor anterior, el nuevo valor, la regla
-- aplicada y el usuario ejecutor, reforzando la trazabilidad del proceso.



-- USO DE SAVEPOINT / ROLLBACK:
-- Explique qué riesgo controló y por qué ese punto de restauración
-- era necesario.
--
-- RESPUESTA:
-- El SAVEPOINT sv_before_adjustment establece un punto de restauración
-- justo antes de las operaciones de escritura. Si la validación
-- intermedia detectara algún empleado cuyo salario superara el tope
-- permitido, se ejecutaría ROLLBACK TO sv_before_adjustment para revertir
-- tanto el INSERT como el UPDATE sin afectar operaciones previas de la
-- sesión, permitiendo corregir y reintentar la transacción de forma
-- segura sin comprometer la integridad de los datos.

PROMPT ===== Fin de plantilla =====
