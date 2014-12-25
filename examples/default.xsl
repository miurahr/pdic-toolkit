<?xml version="1.0"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns="http://www.w3.org/TR/xhtml1/strict">

<xsl:template match="/">
<html>
  <head>
    <title>Greek-Japanese Dictionary</title>
  </head>
  <body>
  <h1>Greek-Japanese Dictionary</h1>
  <xsl:apply-templates/>
  </body>
</html>
</xsl:template>

<xsl:template match="dictionary">
  <xsl:apply-templates/>
</xsl:template>

<xsl:template match="entry">
<div>
  <xsl:variable name="level" select="level"/>
  <xsl:variable name="hw">
    <xsl:variable name="e" select="substring-after(example, '[')"/>
    <xsl:choose>
      <xsl:when test="not($e = '')">
        <xsl:variable name="f" select="substring-before($e, ']')"/>
        <xsl:choose>
          <xsl:when test="$f = ''">
            <xsl:value-of select="headword"/>
          </xsl:when>
          <xsl:when test="contains($f, ',')">
            <xsl:value-of select="substring-before($f, ', ')"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="$f"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="headword"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="grammar">
    <xsl:value-of select="concat(substring-before(example, ']'), '] ')"/>
  </xsl:variable>
  <xsl:variable name="pos">
    <xsl:value-of select="substring-before($grammar, '[')"/>
  </xsl:variable>
  <xsl:variable name="inflection">
    <xsl:variable name="i" select="substring-after($grammar, ', ')"/>
    <xsl:if test="not($i = '')">
       <xsl:value-of select="concat('[', $i)"/>
     </xsl:if>
  </xsl:variable>
  <xsl:variable name="reference">
    <xsl:value-of select="substring-after(example, ']')"/>
  </xsl:variable>
  <b>
  <span>
    <xsl:choose>
      <xsl:when test="level = 0">
        <xsl:attribute name="style">font-size:120%</xsl:attribute>
      </xsl:when>
      <xsl:when test="level = 1">
        <xsl:attribute name="style">font-size:140%</xsl:attribute>
      </xsl:when>
      <xsl:when test="level = 2">
        <xsl:attribute name="style">font-size:160%</xsl:attribute>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="style">font-size:200%</xsl:attribute>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="$hw"/>
  </span>
  </b>
  &#x20;<span style="font-size:90%;font-style:italic"><xsl:value-of select="$pos"/></span>
  &#x20;<xsl:value-of select="definition"/>
  &#x20;<span style="font-size:90%;font-style:italic"><xsl:value-of select="$inflection"/></span>
  &#x20;<span style="font-size:90%;font-style:italic"><xsl:value-of select="$reference"/></span>
</div>
</xsl:template>

</xsl:stylesheet>
