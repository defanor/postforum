
<script src="/js/jquery-2.1.0.min.js" />
<script src="/js/d3.v3.min.js" charset="utf-8"></script>
<script src="/js/dagre-d3.js"/>
<script src="/js/dagre.min.js"/>
<script src="/js/svg-pan-zoom.js"/>
<script src="/js/svg-pan-zoom-control-icons.js"/>


<script src="/js/forum.js" />

<link rel="stylesheet" type="text/css" href="/css/forum.css"/>


<div class="graph_container" id="filter_topics_container">
  <svg id="filter_topics_graph" />
</div>

<div class="graph_container" id="filter_restrictions_container">
  <svg id="filter_restrictions_graph" />
</div>

<div class="graph_container" id="post_topics_container">
  <svg id="post_topics_graph" />
</div>

<div class="graph_container" id="post_restrictions_container">
  <svg id="post_restrictions_graph" />
</div>

<form id="filter">
  Logged in as '<loggedInUser/>' (<a href="/logout">logout</a>)<br/>
  <input type="checkbox" id="remove" /><label for="remove">remove</label><br/>
  <input type="checkbox" id="recursively" checked /><label for="recursively">recursively</label><br/>
  <input type="submit" value="load" />
</form>

<form id="post">
  <div id="post_reply_to">new thread</div><br/>
  <textarea id="post_message" /><br/>
  <input type="submit" value="post" />
</form>

<div id="forumContent" />
