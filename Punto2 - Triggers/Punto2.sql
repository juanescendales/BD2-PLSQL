CREATE OR REPLACE TRIGGER insert_trigger
FOR INSERT
ON INDIVIDUO
COMPOUND TRIGGER
    new_padre INDIVIDUO.PADRE%TYPE := NULL;
    BEFORE EACH ROW IS
    BEGIN
        IF :NEW.NRO_HIJOS <> 0 THEN
            :NEW.NRO_HIJOS := 0;
        END IF;
        IF :NEW.PADRE IS NOT NULL THEN
            new_padre := :NEW.PADRE;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        IF new_padre IS NOT NULL THEN
            UPDATE INDIVIDUO SET NRO_HIJOS = (NRO_HIJOS + 1) WHERE CODIGO = new_padre;
        END IF;
    END AFTER STATEMENT ;
END insert_trigger;


CREATE OR REPLACE TRIGGER delete_trigger
FOR DELETE
ON INDIVIDUO
COMPOUND TRIGGER
    old_codigo INDIVIDUO.CODIGO%TYPE := NULL;

    TYPE individuos_type IS TABLE OF INDIVIDUO%ROWTYPE
    INDEX BY BINARY_INTEGER;

    individuos_array individuos_type;
    BEFORE STATEMENT IS
    BEGIN
        SELECT * BULK COLLECT INTO individuos_array FROM INDIVIDUO;
        UPDATE INDIVIDUO SET PADRE = NULL;
    END BEFORE STATEMENT ;

    BEFORE EACH ROW IS
    BEGIN
        old_codigo  := :OLD.CODIGO;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        FOR i IN individuos_array.FIRST..individuos_array.LAST LOOP
            IF individuos_array(i).CODIGO <> old_codigo THEN
                IF individuos_array(i).PADRE = old_codigo THEN
                    individuos_array(i).PADRE := NULL;
                END IF;
                UPDATE INDIVIDUO SET PADRE = individuos_array(i).PADRE WHERE CODIGO = individuos_array(i).CODIGO;
            ELSE
                IF individuos_array(i).PADRE IS NOT NULL THEN
                    UPDATE INDIVIDUO SET NRO_HIJOS = (NRO_HIJOS - 1) WHERE CODIGO = individuos_array(i).PADRE ;
                END IF;
            END IF;
        END LOOP;
    END AFTER STATEMENT ;
END delete_trigger;


CREATE OR REPLACE TRIGGER update_valor_trigger
FOR UPDATE OF VALOR
ON INDIVIDUO
COMPOUND TRIGGER
    diferencia INDIVIDUO.VALOR%TYPE;
    codigo_padre INDIVIDUO.CODIGO%TYPE;
    aumento BOOLEAN := FALSE;
    TYPE individuos_type IS TABLE OF INDIVIDUO%ROWTYPE
    INDEX BY BINARY_INTEGER;
    hijos_array individuos_type;
    hijo_seleccionado INDIVIDUO%ROWTYPE;
    BEFORE EACH ROW IS BEGIN
        codigo_padre:= :OLD.CODIGO;
        diferencia:= :NEW.VALOR - :OLD.VALOR;
        IF diferencia < 5 AND diferencia > 0 THEN
            RAISE_APPLICATION_ERROR(-20002,'¡Aumento insuficiente, debe ser mayor o igual a 5! - ');
        ELSIF diferencia >= 5 THEN
            :NEW.VALOR := :OLD.VALOR +2;
            aumento := TRUE;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS BEGIN
        IF aumento THEN
            SELECT * BULK COLLECT INTO hijos_array FROM INDIVIDUO WHERE PADRE = codigo_padre ORDER BY CODIGO;
            IF hijos_array.COUNT > 0 THEN
                hijo_seleccionado := hijos_array(1);
                SELECT * BULK COLLECT INTO hijos_array FROM INDIVIDUO WHERE PADRE = hijo_seleccionado.CODIGO;
                DELETE FROM INDIVIDUO WHERE CODIGO = hijo_seleccionado.CODIGO;
                INSERT INTO INDIVIDUO (CODIGO, NOMBRE, VALOR, PADRE, NRO_HIJOS) values (hijo_seleccionado.CODIGO, hijo_seleccionado.NOMBRE, (hijo_seleccionado.VALOR+(diferencia-2)), hijo_seleccionado.PADRE, 0);
                UPDATE INDIVIDUO SET NRO_HIJOS = hijo_seleccionado.NRO_HIJOS WHERE CODIGO = hijo_seleccionado.CODIGO;
                IF hijos_array.COUNT > 0 THEN
                    FOR i IN hijos_array.FIRST .. hijos_array.LAST LOOP
                        UPDATE INDIVIDUO SET PADRE = hijo_seleccionado.CODIGO WHERE CODIGO = hijos_array(i).CODIGO;
                    END LOOP;
                END IF;
            END IF;
        END IF;
    END AFTER STATEMENT;
END update_valor_trigger;

CREATE OR REPLACE TRIGGER update_codigo_trigger
FOR UPDATE OF CODIGO
ON INDIVIDUO
COMPOUND TRIGGER

    old_codigo INDIVIDUO.CODIGO%TYPE := NULL;
    new_codigo INDIVIDUO.CODIGO%TYPE := NULL;
    codigo_padre INDIVIDUO.PADRE%TYPE := NULL;
    TYPE individuos_type IS TABLE OF INDIVIDUO%ROWTYPE
    INDEX BY BINARY_INTEGER;
    individuos_array individuos_type;
    BEFORE STATEMENT IS
    BEGIN
        SELECT * BULK COLLECT INTO individuos_array FROM INDIVIDUO;
        UPDATE INDIVIDUO SET PADRE = NULL;
    END BEFORE STATEMENT ;

    BEFORE EACH ROW IS
    BEGIN
        old_codigo := :OLD.CODIGO;
        new_codigo := :NEW.CODIGO;
        codigo_padre:= :NEW.PADRE;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        FOR i IN individuos_array.FIRST..individuos_array.LAST LOOP
            IF individuos_array(i).CODIGO <> old_codigo AND individuos_array(i).PADRE = old_codigo THEN
                individuos_array(i).PADRE := new_codigo;
            ELSIF individuos_array(i).CODIGO = old_codigo THEN
                individuos_array(i).PADRE := codigo_padre;
            END IF;
            UPDATE INDIVIDUO SET PADRE = individuos_array(i).PADRE WHERE CODIGO = individuos_array(i).CODIGO;
        END LOOP;
    END AFTER STATEMENT ;

END update_codigo_trigger;


