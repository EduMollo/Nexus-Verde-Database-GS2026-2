import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.util.*;
import java.io.*;

/** Executor JDBC: SQL real, sem dependencias alem do driver Oracle. */
public class OracleNexus {
 static final Path ROOT=Path.of(System.getProperty("user.dir"));
 static final List<String> TABLES=List.of("NV_USUARIO","NV_REGIAO","NV_PONTO_AGUA","NV_SOLICITACAO","NV_HISTORICO_STATUS","NV_AUDITORIA");
 static final List<String> PACKAGES=List.of("PKG_NV_SOLICITACOES","PKG_NV_AUDITORIA","PKG_NV_RELATORIOS");
 public static void main(String[] args) throws Exception {
  if(args.length!=1) throw new IllegalArgumentException("Uso: OracleNexus check|install|compile|seed|test|export|all");
  Properties local=new Properties(); Path env=ROOT.resolve(".env");
  if(Files.exists(env)) for(String line:Files.readAllLines(env,StandardCharsets.UTF_8)) {
   int p=line.indexOf('='); if(p>0&&!line.strip().startsWith("#")) {
    String value=line.substring(p+1).strip();
    if(value.length()>=2&&((value.startsWith("\"")&&value.endsWith("\""))||(value.startsWith("'")&&value.endsWith("'")))) value=value.substring(1,value.length()-1);
    local.setProperty(line.substring(0,p).strip(),value);
   }
  }
  Properties config=new Properties();config.setProperty("user",setting("DB_USERNAME",local));config.setProperty("password",setting("DB_PASSWORD",local));
  config.setProperty("oracle.net.CONNECT_TIMEOUT","10000");config.setProperty("oracle.jdbc.ReadTimeout","60000");
  try(Connection c=DriverManager.getConnection(setting("DB_URL",local),config)) {
   c.setAutoCommit(false);
   System.out.println("Oracle "+c.getMetaData().getDatabaseMajorVersion()+" conectado; credenciais omitidas.");
   try(var s=c.createStatement()){s.execute("BEGIN DBMS_OUTPUT.ENABLE(NULL); END;");}
   if(c.getMetaData().getDatabaseMajorVersion()<19) throw new SQLException("Requer Oracle 19c ou superior");
   switch(args[0]) {
    case "check" -> System.out.println("Conexao aprovada; nenhuma alteracao executada.");
    case "install" -> install(c);
    case "compile" -> {for(int i=2;i<=4;i++) script(c,file(i));valid(c);}
    case "seed" -> seed(c);
    case "test" -> {valid(c);script(c,file(7));script(c,file(6));c.rollback();}
    case "demo" -> {valid(c);script(c,"08_consultas_apresentacao.sql");c.rollback();}
    case "export" -> {valid(c);export(c);}
    case "all" -> {
     int tables=count(c,"SELECT COUNT(*) FROM user_tables WHERE table_name IN ('NV_USUARIO','NV_REGIAO','NV_PONTO_AGUA','NV_SOLICITACAO','NV_HISTORICO_STATUS','NV_AUDITORIA')");
     if(tables==0) install(c);
     else if(tables!=6) throw new SQLException("Instalacao parcial NV_: revisar; nenhum objeto sera apagado");
     valid(c);seed(c);script(c,file(7));script(c,file(6));c.rollback();export(c);
    }
    default -> throw new IllegalArgumentException("Acao desconhecida");
   }
   c.rollback();
  }
 }
 static String setting(String name,Properties local) {
  String v=System.getenv(name);if(v==null||v.isBlank())v=local.getProperty(name);
  if(v==null||v.isBlank())throw new IllegalArgumentException("Configure "+name+" no .env local");return v;
 }
 static String file(int i) {return switch(i){case 1->"01_estrutura.sql";case 2->"02_solicitacoes.sql";case 3->"03_auditoria.sql";case 4->"04_relatorios.sql";case 5->"05_carga.sql";case 6->"06_blocos.sql";case 7->"07_testes.sql";default->throw new IllegalArgumentException();};}
 static int count(Connection c,String sql)throws SQLException{try(var s=c.createStatement();var r=s.executeQuery(sql)){r.next();return r.getInt(1);}}
 static void install(Connection c)throws Exception{
  if(count(c,"SELECT COUNT(*) FROM user_objects WHERE object_name LIKE 'NV\\_%' ESCAPE '\\' OR object_name LIKE 'PKG_NV\\_%' ESCAPE '\\' OR object_name LIKE 'TRG_NV\\_%' ESCAPE '\\' OR object_name LIKE 'V_NV\\_%' ESCAPE '\\'")!=0)
   throw new SQLException("Nomes NV_ ocupados: instalacao interrompida para preservar dados");
  for(int i=1;i<=4;i++)script(c,file(i));valid(c);System.out.println("Estrutura instalada.");
 }
 static void valid(Connection c)throws SQLException{
  Set<String> expected=new HashSet<>();for(String p:PACKAGES){expected.add(p+":PACKAGE");expected.add(p+":PACKAGE BODY");}
  for(String t:List.of("TRG_NV_VALIDAR_SOLIC","TRG_NV_AUDITAR_SOLIC"))expected.add(t+":TRIGGER");
  for(String v:List.of("V_NV_FILA","V_NV_DEMANDA","V_NV_ESTOQUE"))expected.add(v+":VIEW");
  for(String t:TABLES)expected.add(t+":TABLE");
  try(var s=c.createStatement();var r=s.executeQuery("SELECT object_name,object_type,status FROM user_objects WHERE object_name LIKE 'NV\\_%' ESCAPE '\\' OR object_name LIKE 'PKG_NV\\_%' ESCAPE '\\' OR object_name LIKE 'TRG_NV\\_%' ESCAPE '\\' OR object_name LIKE 'V_NV\\_%' ESCAPE '\\'")){
   while(r.next()){String k=r.getString(1)+":"+r.getString(2);if(expected.contains(k)){if(!r.getString(3).equals("VALID"))throw new SQLException("Objeto INVALID: "+k);expected.remove(k);}}
  }
  if(!expected.isEmpty())throw new SQLException("Objetos ausentes: "+expected);
  try(var s=c.createStatement();var r=s.executeQuery("SELECT name,line,text FROM user_errors WHERE name LIKE 'PKG_NV\\_%' ESCAPE '\\' OR name LIKE 'TRG_NV\\_%' ESCAPE '\\'")){
   StringBuilder errors=new StringBuilder();while(r.next())errors.append(r.getString(1)).append(':').append(r.getInt(2)).append(' ').append(r.getString(3));
   if(!errors.isEmpty())throw new SQLException(errors.toString());
  }
  if(count(c,"SELECT COUNT(*) FROM user_tab_comments WHERE table_name='NV_USUARIO' AND comments='Nexus Verde GS2026/2 schema-v1'")!=1)throw new SQLException("Versao de estrutura inesperada");
  System.out.println("17 objetos principais VALID; USER_ERRORS vazio.");
 }
 static void seed(Connection c)throws Exception{
  int total=0;for(String t:TABLES)total+=count(c,"SELECT COUNT(*) FROM "+t);
  if(total==0){script(c,file(5));c.commit();}
  else {
   if(count(c,"SELECT COUNT(*) FROM NV_USUARIO")==0||count(c,"SELECT COUNT(*) FROM NV_SOLICITACAO")==0||count(c,"SELECT COUNT(*) FROM NV_PONTO_AGUA")==0)
    throw new SQLException("Carga parcial: revisar antes de continuar");
   System.out.println("Dados existentes preservados; carga nao repetida.");
  }
 }
 static void script(Connection c,String name)throws Exception{
  StringBuilder pending=new StringBuilder();boolean block=false;
  for(String line:Files.readAllLines(ROOT.resolve("sql").resolve(name),StandardCharsets.UTF_8)){
   String t=line.strip();if(t.isEmpty()||t.startsWith("--")||t.matches("(?i)^(SET|PROMPT|WHENEVER|SHOW)\\b.*"))continue;
   if(pending.isEmpty())block=t.matches("(?i)^(DECLARE|BEGIN)\\b.*")||t.matches("(?i)^CREATE\\s+OR\\s+REPLACE\\s+(PACKAGE|TRIGGER)\\b.*");
   if(block&&t.equals("/")){execute(c,pending.toString());pending.setLength(0);block=false;continue;}
   pending.append(line).append('\n');if(!block&&t.endsWith(";")){String sql=pending.toString().strip();execute(c,sql.substring(0,sql.length()-1));pending.setLength(0);}
  }
  if(!pending.toString().isBlank())throw new SQLException("SQL incompleto: "+name);
  output(c);System.out.println(name+": executado.");
 }
 static void execute(Connection c,String sql)throws SQLException{try(var s=c.createStatement()){s.execute(sql);}}
 static void output(Connection c)throws SQLException{
  try(var p=c.prepareCall("BEGIN DBMS_OUTPUT.GET_LINE(?,?); END;")){p.registerOutParameter(1,Types.VARCHAR);p.registerOutParameter(2,Types.INTEGER);
   for(int i=0;i<10000;i++){p.execute();if(p.getInt(2)!=0)break;System.out.println(p.getString(1));}}
 }
 static void export(Connection c)throws Exception{
  c.rollback();try(var s=c.createStatement()){s.execute("SET TRANSACTION READ ONLY");}
  // Os dois datasets e os tres relatorios usam a mesma visao consistente Oracle.
  writeClob(c,"PKG_NV_RELATORIOS.PRC_EXPORTAR_SOLICITACOES","dataset/solicitacoes.json");
  writeClob(c,"PKG_NV_RELATORIOS.PRC_EXPORTAR_PONTOS","dataset/pontos_agua.json");
  String rel="{\"fila\":"+rows(c,"SELECT * FROM V_NV_FILA ORDER BY prioridade DESC,id")+
   ",\"demanda\":"+rows(c,"SELECT * FROM V_NV_DEMANDA ORDER BY \"regiaoId\",status")+
   ",\"estoque\":"+rows(c,"SELECT * FROM V_NV_ESTOQUE ORDER BY \"regiaoId\"")+"}";
  write("evidencias/relatorios_oracle.json",rel);
  write("evidencias/objetos_oracle.json",rows(c,"SELECT object_name,object_type,status FROM user_objects WHERE object_name LIKE 'PKG_NV\\_%' ESCAPE '\\' OR object_name IN ('NV_USUARIO','NV_REGIAO','NV_PONTO_AGUA','NV_SOLICITACAO','NV_HISTORICO_STATUS','NV_AUDITORIA','TRG_NV_VALIDAR_SOLIC','TRG_NV_AUDITAR_SOLIC','V_NV_FILA','V_NV_DEMANDA','V_NV_ESTOQUE') ORDER BY object_name,object_type"));
  c.commit();System.out.println("Datasets e relatorios exportados da mesma transacao somente leitura.");
 }
 static void writeClob(Connection c,String proc,String path)throws Exception{
  try(var p=c.prepareCall("{call "+proc+"(?)}")){p.registerOutParameter(1,Types.CLOB);p.execute();Clob clob=p.getClob(1);
   if(clob==null)throw new SQLException("JSON nulo");try(var r=clob.getCharacterStream()){StringWriter w=new StringWriter();r.transferTo(w);write(path,w.toString());}finally{clob.free();}}
 }
 static void write(String path,String data)throws IOException{
  Path p=ROOT.resolve(path);Files.createDirectories(p.getParent());Path tmp=p.resolveSibling(p.getFileName()+".tmp");
  Files.writeString(tmp,data+"\n",StandardCharsets.UTF_8);Files.move(tmp,p,StandardCopyOption.REPLACE_EXISTING);
 }
 static String quote(String v){return "\""+v.replace("\\","\\\\").replace("\"","\\\"").replace("\n","\\n").replace("\r","\\r").replace("\t","\\t")+"\"";}
 static String rows(Connection c,String sql)throws SQLException{
  StringJoiner result=new StringJoiner(",","[","]");try(var s=c.createStatement();var r=s.executeQuery(sql)){var m=r.getMetaData();while(r.next()){
   StringJoiner row=new StringJoiner(",","{","}");for(int i=1;i<=m.getColumnCount();i++){String label=m.getColumnLabel(i);if(label.equals(label.toUpperCase(Locale.ROOT)))label=label.toLowerCase(Locale.ROOT);Object v=r.getObject(i);row.add(quote(label)+":"+(v==null?"null":v instanceof Number?v.toString():quote(v.toString())));}result.add(row.toString());}}
  return result.toString();
 }
}
