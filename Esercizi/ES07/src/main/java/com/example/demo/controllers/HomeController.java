package com.example.demo.controllers;

import java.net.InetAddress;
import java.net.NetworkInterface;
import java.util.Collections;
import java.util.Enumeration;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HomeController {

    @GetMapping("/")
    public String home() {

        return getNetData();
    }

    private String getNetData() {
        try {
            StringBuilder sb = new StringBuilder();

            InetAddress localHost = InetAddress.getLocalHost();

            String hostName = localHost.getHostName();
            String hostAddress = localHost.getHostAddress();

            sb
                .append("<html><head><title>Deployment per un'app java spring</title></head><body>")
                .append("Host Name: ")
                .append(hostName)
                .append("<br/>Host Address: ")
                .append(hostAddress)
                .append("<br>")
                .append("====================================================")
                .append("<br/>Network Interfaces:<br/>")
                .append("====================================================")
                .append("<br>");

            Enumeration<NetworkInterface> networkInterfaces = NetworkInterface.getNetworkInterfaces();

            for (NetworkInterface networkInterface : Collections.list(networkInterfaces)) {
                Enumeration<InetAddress> inetAddresses = networkInterface.getInetAddresses();

                sb
                    .append("<hr>")
                    .append("Interface: ")
                    .append(networkInterface.getName())
                    .append("<br/>")
                    .append("Display Name: ")
                    .append(networkInterface.getDisplayName())
                    .append("<br/>")
                    .append("Is Up: ")
                    .append(networkInterface.isUp())
                    .append("<br/>")
                    .append("Is Loopback: ")                    
                    .append(networkInterface.isLoopback())
                    .append("<br/>")
                    .append("Is Virtual: ")
                    .append(networkInterface.isVirtual())
                    .append("<br/>");   
                
              
                for (InetAddress inetAddress : Collections.list(inetAddresses)) {
                    sb
                        .append("<br/><br/>")
                        .append("&nbsp;&nbsp;Inet Address: ")
                        .append(inetAddress.getHostAddress())
                        .append("<br/>");
                }

            
            }   

            sb.append("</body></html>");
            
            return sb.toString();

        } catch (Exception e) {
            return "";
        }
    }

}