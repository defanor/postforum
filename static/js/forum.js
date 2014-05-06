var topics_raw = [];
var restrictions_raw = [];
var topics = [];
var restrictions = [];
var filter_topics = [];
var filter_restrictions = [];
var post_topics = [];
var post_restrictions = [];
var thread = 0;
var reply_to = 0;


$(function() {
    if (location.hash) {
        thread = location.hash.substr(1);
    }
    $.get("topics", function(data) {
        topics_raw = JSON.parse(data);
        $.each(topics_raw, function(i,x){
            topics[x[0]] = x[1];
            $.each(x[1][1], function(i,y){                
                if(!topics[y][2]){
                    topics[y][2] = [];
                }
                topics[y][2].push(x[0]);
            });
        });
        drawGraph("#filter_topics_graph", topics_raw,
                  function(node_id) {
                      var func = $("#remove").is(":checked") ? graph_remove : graph_add;
                      if($("#recursively").is(":checked")){
                          graph_rec(topics, func, filter_topics, node_id);
                      } else {
                          func(filter_topics, node_id);
                      }
                  },
                  function (node_id){ return function(node) {
                      if($.inArray(node_id, filter_topics) != -1) {
                          node.attr("class", "node enter activeNode");
                      } else {
                          node.attr("class", "node enter");
                      }
                  }});
        redraw_post();
    });

    $.get("restrictions", function(data) {
        restrictions_raw = JSON.parse(data);
        $.each(restrictions_raw, function (i, x) {
            restrictions[x[0]] = x[1];
            $.each(x[1][1], function(i,y){
                if(!restrictions[y][2]){
                    restrictions[y][2] = [];
                }
                restrictions[y][2].push(x[0]);
            });
        });
        drawGraph("#filter_restrictions_graph", restrictions_raw,
                  function(node_id) {
                      var func = $("#remove").is(":checked") ? graph_remove : graph_add;
                      if($("#recursively").is(":checked")){
                          graph_rec(restrictions, func, filter_restrictions, node_id);
                      } else {
                          func(filter_restrictions, node_id);
                      }
                  },
                  function (node_id){ return function(node) {
                      if($.inArray(node_id, filter_restrictions) != -1) {
                          node.attr("class", "node enter activeNode");
                      } else {
                          node.attr("class", "node enter");
                      }
                  }});
        redraw_post();
    });

    $("#filter").on("submit", function(event) {
        event.preventDefault();
        post_topics = filter_topics.slice();
        post_restrictions = filter_restrictions.slice();
        redraw_post();
        if (thread == 0) {
            $.post("threads", { "filter.topics": filter_topics.join(" "),
                               "filter.restrictions": filter_restrictions.join(" "),
                               "filter.offset": 0,
                               "filter.limit": 100
                             })
                .done(function(data) {
                    drawThreads(JSON.parse(data));
                });
        } else {
            $.post("messages", { "filter.topics": filter_topics.join(" "),
                               "filter.restrictions": filter_restrictions.join(" "),
                               "filter.thread": thread
                             })
                .done(function(data) {
                    drawMessages(thread, JSON.parse(data));
                });
        }
    });
    $("#post").on("submit", function(event) {
        event.preventDefault();
        var req = { "post.topics": post_topics.join(" "),
                    "post.restrictions": post_restrictions.join(" "),
                    "post.message": $("#post_message").val()
                  };
        if(reply_to > 0) {
            req["post.reply_to"] = reply_to;
        }
        $.post("post", req).done(function(data) {
            $("#filter").submit();
        });
    });

});

function redraw_post(){
    drawGraph("#post_topics_graph", topics_raw,
              function(node_id) {
                  var func = $("#remove").is(":checked") ? graph_remove : graph_add;
                  if($("#recursively").is(":checked")){
                      graph_rec(topics, func, post_topics, node_id);
                  } else {
                      func(post_topics, node_id);
                  }
              },
              function (node_id){ return function(node) {
                  if($.inArray(node_id, post_topics) != -1) {
                      node.attr("class", "node enter activeNode");
                  } else {
                      node.attr("class", "node enter");
                  }
              }});
    drawGraph("#post_restrictions_graph", restrictions_raw,
              function(node_id) {
                  var func = $("#remove").is(":checked") ? graph_remove : graph_add;
                  if($("#recursively").is(":checked")){
                      graph_rec(restrictions, func, post_restrictions, node_id);
                  } else {
                      func(post_restrictions, node_id);
                  }
              },
              function (node_id){ return function(node) {
                  if($.inArray(node_id, post_restrictions) != -1) {
                      node.attr("class", "node enter activeNode");
                  } else {
                      node.attr("class", "node enter");
                  }
              }});
}

function nl2br (str, is_xhtml) {
    var breakTag = (is_xhtml || typeof is_xhtml === 'undefined') ? '<br />' : '<br>';
    return (str + '').replace(/([^>\r\n]?)(\r\n|\n\r|\r|\n)/g, '$1' + breakTag + '$2');
}

function createMessageDiv(msg) {
    var msgTopics = $.map(msg.topics, function(n, i) {
        return topics[n][0];
    }).join(", ");
    var msgRestrictions = $.map(msg.restrictions, function(n, i) {
        return restrictions[n][0];
    }).join(", ");

    var idDiv = $("<div/>").addClass("msgID").text("#" + msg.id);
    var topicsDiv = $("<div/>").addClass("topics").text(msgTopics);
    var restrictionsDiv = $("<div/>").addClass("restrictions").text(msgRestrictions);
    var userDiv = $("<div/>").addClass("user").text("by " + msg.login);
    var timeDiv = $("<div/>").addClass("time").text("at " + msg.creation_time);
    var msgMetaDiv = $("<div/>").addClass("messageMeta")
        .append(idDiv)
        .append(userDiv)
        .append(timeDiv)
//        .append(topicsDiv)
//        .append(restrictionsDiv)
    ;
    var msgTextDiv = $("<div/>").addClass("msgText").text(msg.message);
    msgTextDiv.html(nl2br(msgTextDiv.html()));
    var msgDiv = $("<div/>").addClass("message")
        .append(msgMetaDiv)
        .append(msgTextDiv);
    return msgDiv;
}

function drawMessages(root, data){
    $("#forumContent").html("");
    $("#forumContent").append($("<button />")
                              .text("back")
                              .click(function(){
                                  location.hash = "";
                                  thread = 0;
                                  $("#filter").submit();
                                  $("#post_reply_to").text("new thread");
                              }));
    var answers = [];
    var messages = [];
    $.each(data, function (i, msg) {
        if(msg.parent){
            if(!answers[msg.parent]){
                answers[msg.parent] = []
            }
            answers[msg.parent].push(msg.id);
        }
        messages[msg.id] = msg;
    });
    drawMessagesRec(thread, messages, answers, 0);
}

function drawMessagesRec(root, messages, answers, level){
    var msg = messages[root];
    msgDiv = createMessageDiv(msg)
        .click(function(){
            reply_to = msg.id;
            $("#post_reply_to").text("reply to #" + msg.id);
            post_topics = msg.topics.slice();
            post_restrictions = msg.restrictions.slice();
            redraw_post();
        })
        .css("margin-left", (level * 20) + "px");
    $("#forumContent").append(msgDiv);
    if(answers[root] && answers[root].length > 0) {
        $.each(answers[root], function (i, id) {
            drawMessagesRec(id, messages, answers, level + 1);
        });
    }
}

function drawThreads(data){
    $("#forumContent").html("");
    $.each(data, function (i, msg) {
        var threadDiv = createMessageDiv(msg).click(function(){
            thread = msg.id;
            location.hash = thread;
            $("#filter").submit();
        });
        $("#forumContent").append(threadDiv);
    });
}

function drawGraph(name, data, nodeOnClick, nodeOnInit) {
    var g = new dagreD3.Digraph();
    if(data.length > 0) {
        $.each(data, function(i, node){
            g.addNode(node[0], { label: node[1][0], onclick: function(){
                nodeOnClick(node[0]);
                drawGraph(name, data, nodeOnClick, nodeOnInit);
            }, oninit: nodeOnInit(node[0])});
            if(node[1][1].length > 0) {
                $.each(node[1][1], function(j, from){
                    g.addEdge(null, from, node[0], {});
                });
            }
        });
    }

    var renderer = new dagreD3.Renderer();
    renderer.run(g, d3.select(name));

    svgPanZoom.init({
        'selector': name,
        'controlIconsEnabled': false,
        'panEnabled': true, 
        'zoomEnabled': true,
        'dragEnabled': false,
        'zoomScaleSensitivity': 0.2,
        'minZoom': 0.2,
        'maxZoom': 1
    });
}

function graph_rec(graph, func, active, node){
    func(active, node);
    if(graph[node][2] && graph[node][2].length > 0){
        $.each(graph[node][2], function(i,x){
            graph_rec(graph, func, active, x);
        });
    }
}

function graph_add(active, node) {
    if($.inArray(node, active) == -1) {
        active.push(node);
    }
}

function graph_remove(active, node) {
    if($.inArray(node, active) != -1) {
        active.splice($.inArray(node, active), 1);
    }
}
