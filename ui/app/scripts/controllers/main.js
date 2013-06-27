'use strict';

angular.module('uiApp')
  .controller('MainCtrl', function ($scope) {


    $scope.redisCommands = []
    $scope.commands = [
    ];

    $scope.namespaces = [
    ];

    var _commandsIndexes = []
    var _namespacesIndexes = []

    function decodePayload(data) {
        var redisCommand = JSON.parse(data)
        redisCommand.Args = redisCommand.Args.map(atob)
        redisCommand.Ipaddr = atob(redisCommand.Ipaddr)
        return redisCommand
    };


    var handleCallback = function (msg) {
        var redisCommand = decodePayload(msg.data)
        $scope.$apply(function () {
            $scope.redisCommands.unshift(redisCommand)

            if ($scope.commands.length ==0){
                $scope.commands.push({"values": []})
            }

            var _command = redisCommand.Args[0]
            var index = _commandsIndexes.indexOf(_command)
            if(index == -1){
                _commandsIndexes.push(_command)
                $scope.commands[0].values.push({"label":_command, "value": 1})
            } else {
                $scope.commands[0].values[index]["value"]+=1
            }

            if (redisCommand.Args.length > 1) {
                if ($scope.namespaces.length ==0){
                    $scope.namespaces.push({"values": []})
                }
                var namespaces = redisCommand.Args[1].split(":")
                if (namespaces.length > 1) {
                    var namespace = namespaces[0]
                    var index = _namespacesIndexes.indexOf(namespace)
                    if(index == -1){
                        _namespacesIndexes.push(namespace)
                        $scope.namespaces[0].values.push({"label":namespace, "value": 1})
                    } else {
                        $scope.namespaces[0].values[index]["value"]+=1
                    }
                }
            }
        });
    }

    var source = new EventSource('/redis');
    source.addEventListener('message', handleCallback, false);

    $scope.showCommands = true
    $scope.showNamespaces = true

    $scope.chartRenderer = function(el,data) {
	    nv.addGraph(function() {
            var chart = nv.models.pieChart()
            .x(function(d) { return d.label })
            .y(function(d) { return d.value })
            .showLabels(true)
            .labelThreshold(.05)
            .height("240")
            .width("460")
            .donut(true);
 
            el
            .datum(data)
            .transition().duration(1200)
            .call(chart);

            return chart;
	    })
     };

  });
