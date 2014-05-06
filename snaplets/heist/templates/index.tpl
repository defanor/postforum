<apply template="base">

  <ifLoggedIn>
    <apply template="_forum"/>
  </ifLoggedIn>

  <ifLoggedOut>
    <apply template="_login"/>
  </ifLoggedOut>

</apply>
