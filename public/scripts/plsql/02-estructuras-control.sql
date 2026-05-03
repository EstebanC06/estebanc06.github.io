--Estructuras de Control

-- 1. GOTO - primo
DECLARE
    vd_current_date NUMBER := TO_NUMBER(TO_CHAR(SYSDATE, 'DD')); 
BEGIN
    IF vd_current_date IN (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31) THEN
        GOTO proceso_primo;
    ELSE 
        GOTO proceso_noprimo;
    END IF; 
    <<proceso_primo>>
        dbms_output.put_line('HOLA PRIMO');
    <<proceso_noprimo>>
        dbms_output.put_line('NO ES PRIMO');
END;
/

-- 2. WHILE - Fibonacci
DECLARE
    vn_a NUMBER := 0;
    vn_b NUMBER := 1;
BEGIN
    WHILE vn_a <= 100 LOOP
        dbms_output.put_line(vn_a); 
        vn_b := vn_a + vn_b;  
        vn_a := vn_b - vn_a; 
    END LOOP;
END;
/

-- 3. WHILE - MCD y MCM
DECLARE
   a NUMBER := 12;
   b NUMBER := 18;
   mcd NUMBER;
   mcm NUMBER;
   x NUMBER;
   y NUMBER;
BEGIN
   x := a; y := b;
   WHILE y != 0 LOOP
      mcd := MOD(x, y);
      x := y; y := mcd;
   END LOOP;
   mcd := x;
   mcm := (a * b) / mcd;
   DBMS_OUTPUT.PUT_LINE('El MCM es: ' || mcm);
END;
/

-- 4. FOR - raiz cuadrada
DECLARE
    vn_numerouno NUMBER := 49;
    vn_numeroraiz NUMBER := 0;
BEGIN
    FOR vn_numeroraiz IN 1..SQRT(vn_numerouno) LOOP
        IF ((vn_numeroraiz * vn_numeroraiz)= vn_numerouno) THEN 
            dbms_output.put_line(vn_numeroraiz);
        ELSE IF(vn_numerouno = vn_numeroraiz) THEN
            dbms_output.put_line('No tiene raiz');
        END IF;
        END IF;
    END LOOP;
END;
/
