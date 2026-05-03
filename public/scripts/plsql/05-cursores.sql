-- Cursor: primer empleado del depto 80
DECLARE
    CURSOR cursos_empleados_80 IS
        SELECT FIRST_NAME, LAST_NAME FROM DCAICEDOS.employees WHERE department_id = 80;
    nom VARCHAR2(50);
    ape VARCHAR2(50);
BEGIN
    OPEN cursos_empleados_80;
    FETCH cursos_empleados_80 INTO nom, ape;
    dbms_output.put_line(nom || ' ' || ape);
    CLOSE cursos_empleados_80;
END;
/

-- Cursor con LOOP: todos los empleados del depto 80
DECLARE
    CURSOR cursos_empleados_80 IS
        SELECT FIRST_NAME, LAST_NAME FROM DCAICEDOS.employees WHERE department_id = 80;
    nom VARCHAR2(50);
    ape VARCHAR2(50);
BEGIN
    OPEN cursos_empleados_80;
    LOOP
        FETCH cursos_empleados_80 INTO nom, ape;
        EXIT WHEN cursos_empleados_80%NOTFOUND;
        dbms_output.put_line(nom || ' ' || ape);
    END LOOP;
    CLOSE cursos_empleados_80;
END;
/
