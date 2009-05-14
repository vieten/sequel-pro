//
//  SPSQLTokenizer.h
//  sequel-pro
//
//  Created by Hans-J. Bibiko on May 14, 2009
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//
//  More info at <http://code.google.com/p/sequel-pro/>

#define SP_SQL_TOKEN_DOUBLE_QUOTED_TEXT   1
#define SP_SQL_TOKEN_SINGLE_QUOTED_TEXT   2
#define SP_SQL_TOKEN_COMMENT              3
#define SP_SQL_TOKEN_BACKTICK_QUOTED_TEXT 4
#define SP_SQL_TOKEN_DELIM_START          5
#define SP_SQL_TOKEN_DELIM_VALUE          6
#define SP_SQL_TOKEN_DELIM_END            7
#define SP_SQL_TOKEN_WHITESPACE           8
#define SP_SQL_TOKEN_SEMICOLON            9
#define SP_SQL_TOKEN_COMPOUND            10
