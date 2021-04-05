DECLARE
    TYPE row_cerdos_type IS TABLE OF CERDO%ROWTYPE INDEX BY BINARY_INTEGER;
    TYPE row_camiones_type IS TABLE OF CAMION%ROWTYPE INDEX BY BINARY_INTEGER;
    TYPE peso_cerdos_type IS TABLE OF CERDO.PESOKILOS%TYPE INDEX BY BINARY_INTEGER;
    TYPE matriz_desicion_type IS TABLE OF peso_cerdos_type INDEX BY BINARY_INTEGER;
    array_cerdos_global row_cerdos_type;
    array_camiones      row_camiones_type;
    kg_input            CERDO.PESOKILOS%TYPE;
    kg_actual           CERDO.PESOKILOS%TYPE := 0;
    primer_camion       BOOLEAN;

BEGIN
    primer_camion := TRUE;
    kg_input :=: kg_input;
    FOR cerdo IN (SELECT * FROM CERDO)
        LOOP
            array_cerdos_global(cerdo.COD) := cerdo;
        END LOOP;
    SELECT * BULK COLLECT INTO array_camiones FROM CAMION ORDER BY MAXIMACAPACIDADKILOS DESC;

    IF array_camiones.COUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Tabla CAMION se encuentra vacia');
    ELSIF array_cerdos_global.COUNT = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Tabla CERDO se encuentra vacia');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Informe para Mi Cerdito.');
        DBMS_OUTPUT.PUT_LINE('-----');
        FOR indice_camion in array_camiones.FIRST .. array_camiones.LAST
            LOOP
                DECLARE
                    matriz_desicion      matriz_desicion_type;
                    array_cerdos         row_cerdos_type;
                    kg_maximo            CAMION.MAXIMACAPACIDADKILOS%TYPE;
                    numero_cerdos        NUMERIC;
                    seleccionar_cerdo    CERDO.PESOKILOS%TYPE;
                    no_seleccionar_cerdo CERDO.PESOKILOS%TYPE;
                    i                    NUMERIC;
                    j                    NUMERIC;
                    peso                 NUMERIC;
                    maximo_peso_cargado  NUMERIC;
                BEGIN
                    IF (array_camiones(indice_camion).MAXIMACAPACIDADKILOS <= (kg_input - kg_actual)) THEN
                        kg_maximo := array_camiones(indice_camion).MAXIMACAPACIDADKILOS;
                    ELSE
                        kg_maximo := kg_input - kg_actual;
                    END IF;
                    i := array_cerdos_global.FIRST;
                    j := 1;
                    LOOP
                        IF array_cerdos_global(i).PESOKILOS <= kg_maximo THEN
                            array_cerdos(j) := array_cerdos_global(i);
                            j := j + 1;
                        END IF;
                        EXIT WHEN i = array_cerdos_global.LAST;
                        i := array_cerdos_global.NEXT(i);
                    END LOOP;
                    numero_cerdos := array_cerdos.COUNT;
                    FOR i IN 0 .. numero_cerdos
                        LOOP
                            FOR peso_disponible IN 0 .. kg_maximo
                                LOOP
                                    IF (i = 0 OR peso_disponible = 0) THEN
                                        matriz_desicion(i)(peso_disponible) := 0;
                                    ELSIF (array_cerdos(i).PESOKILOS <= peso_disponible) THEN
                                        seleccionar_cerdo := array_cerdos(i).PESOKILOS +
                                                             matriz_desicion(i - 1)(peso_disponible - array_cerdos(i).PESOKILOS);
                                        no_seleccionar_cerdo := matriz_desicion(i - 1)(peso_disponible);
                                        IF (seleccionar_cerdo > no_seleccionar_cerdo) THEN
                                            matriz_desicion(i)(peso_disponible) := seleccionar_cerdo;
                                        ELSE
                                            matriz_desicion(i)(peso_disponible) := no_seleccionar_cerdo;
                                        END IF;
                                    ELSE
                                        matriz_desicion(i)(peso_disponible) := matriz_desicion(i - 1)(peso_disponible);
                                    END IF;
                                END LOOP;
                        END LOOP;
                    maximo_peso_cargado := matriz_desicion(numero_cerdos)(kg_maximo);

                    IF maximo_peso_cargado = 0 THEN
                        IF primer_camion THEN
                            DBMS_OUTPUT.PUT_LINE('El pedido no se puede satisfacer');
                        END IF;
                        EXIT;
                    ELSE
                        primer_camion := FALSE;
                        IF ((kg_actual + maximo_peso_cargado) <= kg_input) THEN
                            DBMS_OUTPUT.PUT_LINE('Camión: ' || array_camiones(indice_camion).IDCAMION);
                            i := numero_cerdos;
                            peso := kg_maximo;
                            DBMS_OUTPUT.PUT('Lista cerdos: ');
                            WHILE matriz_desicion(i)(peso) <> 0 AND i <> 0 AND peso <> 0
                                LOOP
                                    IF matriz_desicion(i)(peso) <> matriz_desicion(i - 1)(peso) THEN
                                        DBMS_OUTPUT.PUT(array_cerdos(i).COD || '(' || array_cerdos(i).NOMBRE || ')' ||
                                                        array_cerdos(i).PESOKILOS || 'kg');
                                        peso := peso - array_cerdos(i).PESOKILOS;
                                        array_cerdos_global.DELETE(array_cerdos(i).COD);
                                        i := i - 1;
                                        IF matriz_desicion(i)(peso) <> 0 AND i <> 0 AND peso <> 0 THEN
                                            DBMS_OUTPUT.PUT(', ');
                                        END IF;
                                    ELSE
                                        i := i - 1;
                                    END IF;
                                END LOOP;
                            DBMS_OUTPUT.PUT_LINE('');
                            DBMS_OUTPUT.PUT_LINE('Total peso cerdos:' || TO_CHAR(maximo_peso_cargado) || 'kg.' ||
                                                 ' Capacidad no usada del camion:' || TO_CHAR(
                                                             array_camiones(indice_camion).MAXIMACAPACIDADKILOS -
                                                             maximo_peso_cargado) || 'kg');
                            kg_actual := kg_actual + maximo_peso_cargado;
                        ELSE
                            EXIT;
                        END IF;
                    END IF;
                END;
            END LOOP;
        DBMS_OUTPUT.PUT_LINE('-----');
        DBMS_OUTPUT.PUT_LINE(
                    'Total Peso solicitado:' || TO_CHAR(kg_input) || 'kg. Peso real enviado:' || TO_CHAR(kg_actual) ||
                    'kg. Peso no satisfecho:' || TO_CHAR(kg_input - kg_actual) || 'kg.');
    END IF;
END;
