# BaturaSys (Java) - container for the shared review site (Render.com).
# Teammates don't need this to work on the code; NetBeans builds the project itself.

# ---- 1. Build: compile the Java classes (JSPs are compiled by Tomcat at runtime)
FROM tomcat:9.0-jdk8-temurin-noble AS build
WORKDIR /app
COPY src/java ./src
COPY web ./web
RUN mkdir -p web/WEB-INF/classes \
 && javac -encoding UTF-8 -nowarn \
      -cp "$CATALINA_HOME/lib/servlet-api.jar" \
      -d web/WEB-INF/classes $(find src -name '*.java')

# ---- 2. Run: Tomcat 9 + Java 8 with an embedded Java DB (Apache Derby)
FROM tomcat:9.0-jre8-temurin-noble
RUN rm -rf "$CATALINA_HOME"/webapps/* && mkdir -p /data/uploads/receipts
# Derby embedded engine (same version as NetBeans 8.2 / GlassFish 4.1.1 Java DB)
ADD https://repo1.maven.org/maven2/org/apache/derby/derby/10.10.2.0/derby-10.10.2.0.jar /usr/local/tomcat/lib/derby.jar
COPY --from=build /app/web /usr/local/tomcat/webapps/ROOT

# The app reads these (see Config.java). On first start the empty database is
# filled with demo data automatically (DbInit). Data resets when the container restarts.
ENV BATURASYS_DB_URL="jdbc:derby:/data/baturasys;create=true;territory=en_US;collation=TERRITORY_BASED:PRIMARY" \
    BATURASYS_DB_USER=app \
    BATURASYS_DB_PASS=app \
    BATURASYS_UPLOAD_DIR=/data/uploads \
    CATALINA_OPTS="-Xmx320m -Dderby.system.home=/data -Djava.security.egd=file:/dev/./urandom"

EXPOSE 8080
CMD ["catalina.sh", "run"]
