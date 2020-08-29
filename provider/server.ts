/// <reference path="product.ts" />

import * as express from "express";

const app = express();
const port = 3000;

app.get("/", (req, res) => {
  const p: ProductAPI.Product = {
    item: "pancakes",
    price: 27.4,
  };
  res.json(p);
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
});
