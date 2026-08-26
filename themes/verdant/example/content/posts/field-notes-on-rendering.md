---
title: Field notes on server-side rendering
date: 2024-03-08
author: Ada Whitlock
summary: Why sending HTML over the wire keeps getting cheaper, and what that means for small teams.
tags:
  - trellis
  - web
---

Rendering on the server never went away; it got quieter. The trade that once looked settled — ship a bundle,
hydrate, reconcile — reads differently when the page is mostly text and the interaction budget is a handful of
form posts.

## What actually costs

A server-rendered page pays once, at request time, for work the client would otherwise repeat on every visitor's
device. That bill scales with traffic rather than with the slowest phone in your audience.

## Where it stops being simple

Anything genuinely stateful — a canvas, a live editor — still wants to live in the browser. The useful question is
not which side renders, but how small the client-side island can be.
