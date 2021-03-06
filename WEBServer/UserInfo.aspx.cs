﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Data.Common;
using System.Data.SqlClient;
using System.Web.UI.WebControls;

public partial class UserInfo : System.Web.UI.Page
{
    private DbHelper dbh;
    private DbDataReader dbr;
    private String id;

    protected void Page_Load(object sender, EventArgs e)
    {
        if (Session["uname"] == null)
        {
            Response.Write("<script>alert('系统超时或非法登录，请重新登录！');window.location.href='default.aspx';</script>");
            return;
        }
        if (Session["uid"]==null)
        {
            Response.Write("<script>alert('系统超时或非法登录，请重新登录！');window.location.href='default.aspx';</script>");
            return;
        }

        if (Session["ucount"] == null)
        {
            Response.Write("<script>alert('系统超时或非法登录，请重新登录！');window.location.href='default.aspx';</script>");
            return;
        }
        string uid = Session["uid"].ToString();
        dbh = new DbHelper();
        string sql;
        sql = string.Format("select count(*) from userinfo where parent_id='{0}' ", uid);
        DbCommand dbc = dbh.GetSqlStringCommond(sql);
             

        int count=int.Parse(dbh.ExecuteScalar(dbc).ToString());
    
        int usercount = int.Parse(Session["ucount"].ToString()); ;
        if (count >= usercount)
        {
            Response.Write("<script>alert('用户最大数超出设定范围，请联系管理员！');window.location.href='userlist.aspx';</script>");
            return;
        }


        if (Request["id"] != null)
        {
            
            id = Request["id"];
             
            sql = string.Format("select * from userinfo where id='{0}' ", Request["id"]);
            DbCommand dbc3 = dbh.GetSqlStringCommond(sql);
            dbr = dbh.ExecuteReader(dbc3);
            dbr.Read();
            tb_guid.Text = dbr["guid"].ToString();
            tb_memo.Text = dbr["memo"].ToString();
            tb_buydate.Text = dbr["buy_date"].ToString();
            tb_stopdate.Text = dbr["stop_date"].ToString();
            tb_username.Text = dbr["user_name"].ToString();
            rb_stop.Checked = dbr["active"].ToString() == "0" ? true : false;
            rb_active.Checked = dbr["active"].ToString() == "0" ? false : true;

        }
        else
        {
            tb_guid.ReadOnly = false;
            tb_buydate.Text = DateTime.Now.ToString("yyyyMMdd");
            tb_stopdate.Text = DateTime.Now.AddYears(1).ToString("yyyyMMdd");
            rb_stop.Checked = true;
        }
    }
    protected void Button1_Click(object sender, EventArgs e)
    {
        if (id == null)
        {
            String SQL = "insert into userinfo (guid   ,user_name  ,buy_date   ,stop_date  ,active  ,memo,parent_id) values ('{0}','{1}','{2}','{3}',{4},'{5}','{6}' )";

            SQL = string.Format(SQL, tb_guid.Text, tb_username.Text, tb_buydate.Text, tb_stopdate.Text, rb_active.Checked ? "1" : "0", tb_memo.Text, Session["uid"].ToString());
            DbCommand dbc = dbh.GetSqlStringCommond(SQL);
              dbh.ExecuteNonQuery(dbc);
        }
        else
        {
            String SQL = "update userinfo  set guid='{0}'   ,user_name='{1}'  ,buy_date='{2}'   ,stop_date='{3}'  ,active={4}  ,memo={5} where id={6}";

            SQL = string.Format(SQL, tb_guid.Text, tb_username.Text, tb_buydate.Text, tb_stopdate.Text, rb_active.Checked ? "1" : "0", tb_memo.Text,id);
           
            DbCommand dbc = dbh.GetSqlStringCommond(SQL);
             dbh.ExecuteNonQuery(dbc);
        }
        Response.Write("<script> window.location.href='userlist.aspx';</script>");

    }
}
