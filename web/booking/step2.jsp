<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="com.baturasys.*" %><%
// Step 2 is now merged into step 1 (cart builder). Redirect accordingly.
Ctx c = new Ctx(request, response);
c.redirect(c.BASE + (c.cart().isEmpty() ? "booking/step1.jsp" : "booking/step3.jsp"));
%>
