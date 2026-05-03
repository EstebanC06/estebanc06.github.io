db.selecciones.insertMany([
    {nombre: "Colombia", colorCamiseta: "Amarrillo", capital: "Bogotá", poblacion: 60000000},
    {nombre: "Inglaterra", capital: "Londres", mundialesGanados: 1},
    {nombre: "Republica del Congo", edadPromedio: 15, continente: "África"}
]);

use("db_2026")
db.patrocinadores.insertMany([
    {nombre: "Adidas", paisOrigen: "Alemania", categoria: "Equipamiento Deportivo" },
    {nombre: "Coca-Cola", paisOrigen: "Estados Unidos", categoria: "Bebidas" },
    {nombre: "Visa", paisOrigen: "Estados Unidos", categoria: "Tecnología de Pagos" },
    {nombre: "Qatar Airways", paisOrigen: "Catar", categoria: "Aerolínea" },
    {nombre: "Hyundai-Kia", paisOrigen: "Corea del Sur", categoria: "Automotriz" },
    {nombre: "Aramco", paisOrigen: "Arabia Saudita", categoria: "Energía" },
    {nombre: "Lenovo", paisOrigen: "China", categoria: "Tecnología" }
]);

use("db_2026")
db.estadios.insertMany([
  { nombre: "Mercedes-Benz Stadium", pais: "Estados Unidos", ciudad: "Atlanta", capacidad: 71000, inauguracion: 2017 },
  { nombre: "Gillette Stadium", pais: "Estados Unidos", ciudad: "Boston", superficie: "Césped sintético", equipoLocal: "New England Patriots" },
  { nombre: "Estadio Azteca", pais: "México", ciudad: "Ciudad de México", capacidad: 87000, altitudMetros: 2200 },
  { nombre: "SoFi Stadium", pais: "Estados Unidos", ciudad: "Los Ángeles", techo: true, costoMillonesUsd: 5000 },
  { nombre: "BMO Field", pais: "Canadá", ciudad: "Toronto", equipoLocal: "Toronto FC", renovado: 2016 }
]);

use("db_2026")
db.jugadores.insertMany([
    {nombre: "Luis Díaz", club: "Bayern Munchen", paisRepresentado: "Colombia", posicion: "Extremo"},
    {nombre: "Cristiano Ronaldo", club: "Al Nassr", paisRepresentado: "Portugal", posicion: "Delantero"},
    {nombre: "Lionel Messi", club: "Inter Miami", paisRepresentado: "Argentina", posicion: "Falso 9"},
    {nombre: "Kylian Mbappé", club: "Real Madrid", paisRepresentado: "Francia", posicion: "Extremo"},
    {nombre: "Pedri González", club: "Barcelona", paisRepresentado: "España", posicion: "Mediocampista"},
]);

use("db_2026")
db.grupos.insertMany([
    {letra: "A", primerPuesto: "Corea del Sur", segundoPuesto: "México", integrantes: ["México", "Corea del Sur", "Sudáfrica", "Chequia"]},
    {letra: "B", primerPuesto: "Suiza", segundoPuesto: "Bosnia y Herzegovina", integrantes: ["Canadá", "Bosnia y Herzegovina", "Qatar", "Suiza"]},
    {letra: "C", primerPuesto: "Brasil", segundoPuesto: "Marruecos", integrantes: ["Brasil", "Marruecos", "Haití", "Escocia"]},
    {letra: "D", primerPuesto: "Turkiye", segundoPuesto: "Paraguay", integrantes: ["USA", "Paraguay", "Australia", "Turkiye"]},
    {letra: "E", primerPuesto: "Alemania", segundoPuesto: "Ecuador", integrantes: ["Alemania", "Ecuador", "Curazao", "Costa de Marfil"]},
]);
