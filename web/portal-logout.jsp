<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="com.baturasys.*" %><%
Ctx c = new Ctx(request, response);
c.logoutAll();
c.redirect(c.BASE + "index.jsp");
%>
