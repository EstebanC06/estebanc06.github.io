-- Listado por departamento con variable de sustitución
DECLARE
    v_dept NUMBER := &Ingrese_Departamento;
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM employees WHERE department_id = v_dept;
    IF v_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No existen empleados en el departamento ' || v_dept);
    ELSE
        DBMS_OUTPUT.PUT_LINE('Empleados del departamento ' || v_dept || ':');
        FOR emp IN (SELECT first_name, last_name FROM DCAICEDOS.employees WHERE department_id = v_dept) LOOP
            DBMS_OUTPUT.PUT_LINE(emp.first_name || ' ' || emp.last_name);
        END LOOP;
        DBMS_OUTPUT.PUT_LINE('Total empleados: ' || v_count);
    END IF;
END;
/

-- Procedimiento nómina mensual
CREATE OR REPLACE PROCEDURE calculate_monthly_payroll(p_period_code VARCHAR2)
IS
    v_period_id pay_periods.period_id%TYPE;
    CURSOR c_employees IS
        SELECT employee_id, first_name || ' ' || last_name AS full_name, salary
        FROM employees WHERE salary IS NOT NULL;
    CURSOR c_devengo IS
        SELECT default_rate FROM pay_concepts WHERE concept_type = 'DEVENGO' AND calc_method = 'PORCENTAJE' AND is_active = 'Y' AND ROWNUM = 1;
    CURSOR c_deduccion IS
        SELECT default_rate FROM pay_concepts WHERE concept_type = 'DEDUCCION' AND calc_method = 'PORCENTAJE' AND is_active = 'Y' AND ROWNUM = 1;
    v_total_devengos    NUMBER(12,2);
    v_total_deducciones NUMBER(12,2);
    v_dev_rate          NUMBER(12,4) := 0;
    v_ded_rate          NUMBER(12,4) := 0;
BEGIN
    SELECT period_id INTO v_period_id FROM pay_periods WHERE period_code = p_period_code AND status = 'ABIERTO';
    OPEN c_devengo;   FETCH c_devengo   INTO v_dev_rate; CLOSE c_devengo;
    OPEN c_deduccion; FETCH c_deduccion INTO v_ded_rate; CLOSE c_deduccion;
    FOR emp IN c_employees LOOP
        v_total_devengos    := emp.salary + (emp.salary * NVL(v_dev_rate,0));
        v_total_deducciones := emp.salary * NVL(v_ded_rate,0);
        DBMS_OUTPUT.PUT_LINE('Empleado: ' || emp.full_name || ' | Neto: ' || ROUND(v_total_devengos - v_total_deducciones,2));
    END LOOP;
EXCEPTION
    WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('Periodo inexistente o cerrado.');
    WHEN OTHERS        THEN DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
END;
/
