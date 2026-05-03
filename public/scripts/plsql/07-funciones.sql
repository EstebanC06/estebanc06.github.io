-- Función: buscar apellido por nombre
CREATE OR REPLACE FUNCTION fn_nombre(nombre_empleado VARCHAR2)
RETURN VARCHAR2 IS
    resultado VARCHAR2(50);
BEGIN
    SELECT EMPLOYEES.LAST_NAME INTO resultado FROM EMPLOYEES WHERE FIRST_NAME = nombre_empleado;
    RETURN 'Hola ' || resultado;
END;
/

DECLARE
    Valor VARCHAR2(50);
BEGIN
    Valor := fn_nombre('Betty');
    DBMS_OUTPUT.PUT_LINE(Valor);
END;
/

-- Función: integral definida de x² (método del trapecio)
CREATE OR REPLACE FUNCTION fn_calcular_integral(
    limite_inf      NUMBER,
    limite_superior NUMBER,
    num_intervalos  NUMBER
) RETURN NUMBER IS
    v_h   NUMBER;
    v_sum NUMBER := 0;
    v_x   NUMBER;
BEGIN
    v_h := (limite_superior - limite_inf) / num_intervalos;
    FOR i IN 0 .. num_intervalos LOOP
        v_x := limite_inf + i * v_h;
        IF i = 0 OR i = num_intervalos THEN
            v_sum := v_sum + (v_x * v_x);
        ELSE
            v_sum := v_sum + 2 * (v_x * v_x);
        END IF;
    END LOOP;
    RETURN (v_h / 2) * v_sum;
END;
/
