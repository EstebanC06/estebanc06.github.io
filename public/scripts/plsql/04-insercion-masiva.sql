-- Insertar 80 conceptos de nómina
DECLARE
    v_concept_type  VARCHAR2(10);
    v_calc_method   VARCHAR2(15);
    v_default_rate  NUMBER(12,4);
BEGIN
    FOR i IN 1..80 LOOP
        IF MOD(i,2) = 0 THEN v_concept_type := 'DEVENGO'; ELSE v_concept_type := 'DEDUCCION'; END IF;
        CASE TRUNC(DBMS_RANDOM.VALUE(1,5))
            WHEN 1 THEN v_calc_method := 'FIJO';
            WHEN 2 THEN v_calc_method := 'PORCENTAJE';
            WHEN 3 THEN v_calc_method := 'POR_HORA';
            WHEN 4 THEN v_calc_method := 'POR_DIA';
        END CASE;
        IF v_calc_method = 'PORCENTAJE' THEN
            v_default_rate := ROUND(DBMS_RANDOM.VALUE(0.01,0.20),4);
        ELSIF v_calc_method IN ('POR_HORA','POR_DIA') THEN
            v_default_rate := ROUND(DBMS_RANDOM.VALUE(0.5,2),4);
        ELSE v_default_rate := NULL;
        END IF;
        INSERT INTO pay_concepts (code, name, concept_type, calc_method, default_rate, is_active)
        VALUES ('CONC_' || LPAD(i,3,'0'), 'Concepto Generado ' || i, v_concept_type, v_calc_method, v_default_rate, 'Y');
    END LOOP;
END;
/

Select * from pay_concepts;

-- Generar periodos 2026
DECLARE
    v_start DATE := DATE '2026-01-01';
    v_end   DATE;
BEGIN
    FOR i IN 1..12 LOOP
        v_end := LAST_DAY(ADD_MONTHS(v_start, i-1));
        INSERT INTO pay_periods (payroll_type_id, period_code, date_start, date_end, status)
        VALUES (1, TO_CHAR(ADD_MONTHS(v_start, i-1),'YYYY-MM'), TRUNC(ADD_MONTHS(v_start, i-1),'MM'), v_end, 'ABIERTO');
    END LOOP;
    FOR i IN 1..12 LOOP
        INSERT INTO pay_periods (payroll_type_id, period_code, date_start, date_end, status)
        VALUES (2, TO_CHAR(ADD_MONTHS(v_start,i-1),'YYYY-MM')||'-Q1', TRUNC(ADD_MONTHS(v_start,i-1),'MM'), TRUNC(ADD_MONTHS(v_start,i-1),'MM') + 14, 'ABIERTO');
        INSERT INTO pay_periods (payroll_type_id, period_code, date_start, date_end, status)
        VALUES (2, TO_CHAR(ADD_MONTHS(v_start,i-1),'YYYY-MM')||'-Q2', TRUNC(ADD_MONTHS(v_start,i-1),'MM') + 15, LAST_DAY(ADD_MONTHS(v_start,i-1)), 'ABIERTO');
    END LOOP;
    FOR i IN 0..51 LOOP
        INSERT INTO pay_periods (payroll_type_id, period_code, date_start, date_end, status)
        VALUES (3, '2026-W' || LPAD(i+1,2,'0'), v_start + (i*7), v_start + (i*7) + 6, 'ABIERTO');
    END LOOP;
END;
/
