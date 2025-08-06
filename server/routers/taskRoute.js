// server/routes/taskRoute.js
const { Router } = require('express');
const { TodoRecord } = require('../records/todo.record');

const TodoRouter = Router();

TodoRouter.get('/', async (req, res) => {
  const todosList = await TodoRecord.listAll();
  res.send(todosList);
});

TodoRouter.get("/health",(req,res)=>{
  res.status(200).send("OK");
})

TodoRouter.post('/create', async (req, res) => {
  const newTodo = new TodoRecord(req.body);
  await newTodo.insert();
  res.send('Values inserted successfully');
});

TodoRouter.delete('/:id', async (req, res) => {
  const todo = await TodoRecord.getOne(req.params.id);
  await todo.delete();
  res.send('Deleted successfully');
});

TodoRouter.put('/update/:id', async (req, res) => {
  const todo = await TodoRecord.getOne(req.params.id);
  await todo.update(req.body.id, req.body.todo);
  res.send('Updated successfully');
});

module.exports = {
  TodoRouter,
};
