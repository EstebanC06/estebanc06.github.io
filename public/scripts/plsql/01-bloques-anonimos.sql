-- Bloque 1: Hola Mundo
DECLARE
    vv_holaworld VARCHAR2(50) := 'Hola Mundo';
BEGIN
    vv_holaworld := 'Hola Mundo';
    dbms_output.put_line(vv_holaworld);
END;
/

-- Bloque 2: %ROWTYPE
DECLARE
    vv_empleado HR.EMPLOYEES%ROWTYPE;
BEGIN
    SELECT * INTO vv_empleado FROM HR.EMPLOYEES WHERE EMPLOYEE_ID = 110;
    dbms_output.put_line('El nombre del empleado es : ' || vv_empleado.LAST_NAME);
END;
/

-- Bloque 3: %TYPE
DECLARE
    vv_nombre   HR.EMPLOYEES.FIRST_NAME%TYPE;
    vv_apellido HR.EMPLOYEES.LAST_NAME%TYPE;    
BEGIN
    SELECT FIRST_NAME, LAST_NAME INTO vv_nombre, vv_apellido
    FROM HR.EMPLOYEES WHERE EMPLOYEE_ID = 110;
    dbms_output.put_line('El nombre del empleado es : ' || vv_nombre);
    dbms_output.put_line('El apellido del empleado es: ' || vv_apellido);
END;
/
